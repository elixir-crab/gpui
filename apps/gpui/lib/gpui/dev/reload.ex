defmodule GPUI.Dev.Reload do
  @moduledoc """
  Development-time source reloading for a running GPUI runtime.

  `watch/2` watches explicitly listed Elixir source files, recompiles a changed
  file, and asks the runtime to render its existing windows again. Window
  assigns remain authoritative, so ordinary `render/1`, `handle_event/3`, and
  `handle_info/2` edits take effect without reopening the native window.

  A watcher may receive a `:notify` PID. After every attempted file reload it
  receives `{:gpui_reload, watcher, path, {:ok, modules}}` or
  `{:gpui_reload, watcher, path, {:error, reason}}`. Files are parsed before
  compilation so syntax failures cannot unload or partially redefine the live
  root module.

  This facility is intended for trusted local development source. It requires
  the optional `:file_system` dependency; applications that do not use source
  reload do not need to start or include it. The watcher does not reload native
  code, remount applications, or migrate changed state shapes.
  """

  use GenServer

  require Logger

  @default_debounce 100

  @doc "Starts a source watcher linked to the caller."
  @spec watch(GenServer.server(), keyword()) :: GenServer.on_start()
  def watch(runtime, opts) do
    GenServer.start_link(__MODULE__, Keyword.put(opts, :runtime, runtime))
  end

  @doc "Keeps an example alive and enables source reloading under `mix gpui.dev`."
  @spec wait(GenServer.server(), keyword()) :: no_return()
  def wait(runtime, opts) do
    if System.get_env("GPUI_DEV_RELOAD") == "1" do
      {:ok, _watcher} = watch(runtime, opts)
    end

    Process.sleep(:infinity)
  end

  @impl GenServer
  def init(opts) do
    with :ok <- ensure_file_system(),
         {:ok, files} <- normalize_files(Keyword.fetch!(opts, :files)),
         {:ok, watcher} <- start_file_system(files) do
      :ok = apply(FileSystem, :subscribe, [watcher])

      state = %{
        runtime: Keyword.fetch!(opts, :runtime),
        files: MapSet.new(files),
        watcher: watcher,
        changed: MapSet.new(),
        timer: nil,
        debounce: Keyword.get(opts, :debounce, @default_debounce),
        notify: Keyword.get(opts, :notify)
      }

      Logger.info(
        "GPUI dev reload watching #{Enum.map_join(files, ", ", &Path.relative_to_cwd/1)}"
      )

      {:ok, state}
    end
  end

  @impl GenServer
  def handle_info({:file_event, watcher, {path, events}}, %{watcher: watcher} = state) do
    path = path |> to_string() |> canonical_path()

    state =
      if MapSet.member?(state.files, path) and reload_event?(events) do
        state
        |> Map.update!(:changed, &MapSet.put(&1, path))
        |> schedule_reload()
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({:file_event, watcher, :stop}, %{watcher: watcher} = state) do
    {:stop, :file_watcher_stopped, state}
  end

  def handle_info(:reload, state) do
    changed = state.changed
    state = %{state | timer: nil, changed: MapSet.new()}

    for path <- Enum.sort(changed) do
      result = reload_file(path, state.runtime)
      notify_reload(state.notify, self(), path, result)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp ensure_file_system do
    if Code.ensure_loaded?(FileSystem) do
      :ok
    else
      {:stop, "GPUI source reloading requires the :file_system dependency in development"}
    end
  end

  defp normalize_files(files) when is_list(files) and files != [] do
    files = files |> Enum.map(&canonical_path/1) |> Enum.uniq()

    case Enum.reject(files, &File.regular?/1) do
      [] -> {:ok, files}
      missing -> {:stop, "reload source files do not exist: #{Enum.join(missing, ", ")}"}
    end
  end

  defp normalize_files(_files), do: {:stop, ":files must contain at least one source path"}

  defp start_file_system(files) do
    directories = files |> Enum.map(&Path.dirname/1) |> Enum.uniq()
    apply(FileSystem, :start_link, [[dirs: directories]])
  end

  defp canonical_path(path) do
    path = Path.expand(path)
    segments = Path.split(path)

    Enum.reduce(segments, "", &resolve_path_segment/2)
  end

  defp resolve_path_segment(segment, current) do
    candidate = if current == "", do: segment, else: Path.join(current, segment)

    case :file.read_link(String.to_charlist(candidate)) do
      {:ok, target} -> resolve_link_target(List.to_string(target), current)
      {:error, _reason} -> candidate
    end
  end

  defp resolve_link_target(target, current) do
    if Path.type(target) == :absolute, do: target, else: Path.expand(target, current)
  end

  defp reload_event?(events), do: Enum.any?(events, &(&1 in [:closed, :modified, :renamed]))

  defp schedule_reload(%{timer: nil, debounce: debounce} = state) do
    %{state | timer: Process.send_after(self(), :reload, debounce)}
  end

  defp schedule_reload(state), do: state

  defp reload_file(path, runtime) do
    previous = Code.get_compiler_option(:ignore_module_conflict)
    relative_path = Path.relative_to_cwd(path)
    Code.put_compiler_option(:ignore_module_conflict, true)

    try do
      modules =
        path
        |> File.read!()
        |> Code.string_to_quoted!(file: path)
        |> then(fn _quoted -> Code.compile_file(path) end)
        |> Enum.map(&elem(&1, 0))

      case GPUI.Runtime.refresh(runtime) do
        {:ok, _snapshot} ->
          Logger.info("GPUI reloaded #{relative_path} (#{inspect(modules)})")
          {:ok, modules}

        {:error, reason} ->
          Logger.error(
            "GPUI compiled #{relative_path}, but refresh failed: #{format_reason(reason)}"
          )

          {:error, {:refresh_failed, reason}}
      end
    catch
      :error, reason when is_exception(reason) ->
        log_reload_failure(relative_path, :error, reason, __STACKTRACE__)
        {:error, {:compile_failed, :error, reason}}

      kind, reason ->
        log_reload_failure(relative_path, kind, reason, __STACKTRACE__)
        {:error, {:compile_failed, kind, reason}}
    after
      Code.put_compiler_option(:ignore_module_conflict, previous)
    end
  end

  defp notify_reload(nil, _watcher, _path, _result), do: :ok

  defp notify_reload(pid, watcher, path, result) when is_pid(pid) do
    send(pid, {:gpui_reload, watcher, path, result})
    :ok
  end

  defp log_reload_failure(path, kind, reason, stacktrace) do
    Logger.error("GPUI could not reload #{path}:\n#{Exception.format(kind, reason, stacktrace)}")
  end

  defp format_reason({:render_failed, error, stacktrace}) when is_exception(error),
    do: Exception.format(:error, error, stacktrace)

  defp format_reason(reason), do: inspect(reason)
end
