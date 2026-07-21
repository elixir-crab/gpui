Code.require_file("analysis.exs", __DIR__)

defmodule Examples.ImagePalette.View do
  use GPUI.View

  alias Examples.ImagePalette.Analysis
  alias GPUI.ResourceRef
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col w-[1000px] h-[720px] bg-slate-900">
      <div class="flex flex-col gap-3 p-5" style={[background: {:rgb, 0x1E293B}]}>
        <div class="flex flex-col gap-1">
          <text class="text-white text-2xl font-semibold">Image palette</text>
          <text style={[color: {:rgb, 0x94A3B8}]}>Decode an image, inspect its dominant colors, and export CSS variables.</text>
        </div>
        <div class="flex items-center gap-3">
          <UI.file_picker
            id="image-file-picker"
            label={picker_label(assigns.status)}
            prompt="Choose an image"
            max_bytes={25 * 1_024 * 1_024}
            phx-change="image_file_selected"
          />
          {cancel_button(assigns)}
          <text style={[color: {:rgb, 0x94A3B8}]}>{source_label(assigns)}</text>
        </div>
        {progress(assigns)}
      </div>

      <div class="flex h-[540px]">
        <div class="flex items-center justify-center w-[620px] h-[540px] p-5" style={[background: {:rgb, 0x0F172A}]}>
          {preview(assigns)}
        </div>
        <div class="flex flex-col w-[380px] h-[540px] gap-3 p-5" style={[background: {:rgb, 0x111827}]}>
          {palette_panel(assigns)}
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event(
        "image_file_selected",
        %{value: %{status: :selected, name: name}},
        assigns
      ) do
    {:noreply,
     %{
       assigns
       | status: :loading,
         progress: 0,
         stage: "Queued",
         error: nil,
         source_name: name,
         job_id: assigns.job_id + 1
     }}
  end

  def handle_event("image_file_selected", %{value: %{status: :cancelled}}, assigns) do
    status = if assigns.image, do: :ready, else: :idle
    {:noreply, %{assigns | status: status, stage: "Selection cancelled", error: nil}}
  end

  def handle_event("image_file_selected", %{value: %{status: :error, reason: reason}}, assigns),
    do: {:noreply, %{assigns | status: :error, stage: "Selection failed", error: reason}}

  def handle_event("export_path_changed", %{value: export_path}, assigns),
    do: {:noreply, %{assigns | export_path: export_path}}

  def handle_event("load_image", _event, assigns) do
    if String.trim(assigns.path) == "" do
      {:noreply, assigns}
    else
      {:noreply,
       %{
         assigns
         | status: :loading,
           progress: 0,
           stage: "Queued",
           error: nil,
           job_id: assigns.job_id + 1
       }}
    end
  end

  def handle_event("cancel_load", _event, assigns) do
    status = if assigns.image, do: :ready, else: :idle

    {:noreply,
     %{
       assigns
       | status: status,
         progress: 0,
         stage: "Analysis cancelled",
         error: nil,
         job_id: assigns.job_id + 1
     }}
  end

  def handle_event("palette_copied", _event, assigns),
    do: {:noreply, %{assigns | status: :copied, stage: "CSS copied to clipboard", error: nil}}

  def handle_event("select_color:" <> hex, _event, assigns) do
    selected =
      if palette_interactive?(assigns) and Enum.any?(assigns.palette, &(&1.hex == hex)),
        do: hex,
        else: assigns.selected

    {:noreply, %{assigns | selected: selected}}
  end

  def handle_event("export_palette", _event, assigns) do
    if palette_interactive?(assigns) and String.trim(assigns.export_path) != "" do
      {:noreply, %{assigns | status: :exporting, error: nil}}
    else
      {:noreply, assigns}
    end
  end

  @impl GPUI.View
  def handle_info({:image_progress, job_id, percent, stage}, %{job_id: job_id} = assigns),
    do: {:noreply, %{assigns | progress: percent, stage: stage}}

  def handle_info(
        {:image_loaded, job_id, width, height, palette},
        %{job_id: job_id} = assigns
      ) do
    {:noreply,
     %{
       assigns
       | status: :ready,
         progress: 100,
         stage: "Ready",
         error: nil,
         image: ResourceRef.new("image-palette-preview", :raster),
         image_width: width,
         image_height: height,
         palette: palette,
         selected: palette |> List.first() |> then(&if(&1, do: &1.hex))
     }}
  end

  def handle_info({:image_failed, job_id, message}, %{job_id: job_id} = assigns),
    do: {:noreply, %{assigns | status: :error, error: message, stage: "Failed"}}

  def handle_info({:palette_exported, path}, assigns),
    do: {:noreply, %{assigns | status: :exported, stage: "Saved #{path}", error: nil}}

  def handle_info({:palette_export_failed, message}, assigns),
    do: {:noreply, %{assigns | status: :ready, error: message}}

  def handle_info(_message, assigns), do: {:noreply, assigns}

  defp cancel_button(%{status: :loading}) do
    ~GPUI"""
    <UI.button id="cancel-analysis" label="Cancel" phx-click="cancel_load" />
    """
  end

  defp cancel_button(_assigns) do
    ~GPUI"""
    <div />
    """
  end

  defp progress(%{status: :loading} = assigns) do
    ~GPUI"""
    <UI.progress
      id="image-progress"
      label={assigns.stage}
      value={assigns.progress}
      max={100}
      class="w-[880px]"
    />
    """
  end

  defp progress(assigns) do
    ~GPUI"""
    <text style={[color: status_color(assigns.status)]}>{status_text(assigns)}</text>
    """
  end

  defp preview(%{image: nil, status: :error} = assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center gap-2 p-5">
      <text class="text-white text-xl">Unable to load image</text>
      <text style={[color: {:rgb, 0xFCA5A5}]}>{assigns.error}</text>
    </div>
    """
  end

  defp preview(%{image: nil}) do
    ~GPUI"""
    <div class="flex flex-col items-center gap-2 p-5">
      <text class="text-white text-xl">No image loaded</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Choose a local image to begin.</text>
    </div>
    """
  end

  defp preview(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center gap-3">
      <img raster={assigns.image} label="Loaded image preview" />
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.image_width} × {assigns.image_height} pixels</text>
    </div>
    """
  end

  defp palette_panel(%{palette: []} = assigns) do
    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">Dominant colors</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{palette_empty_text(assigns.status)}</text>
    </div>
    """
  end

  defp palette_panel(assigns) do
    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">Dominant colors</text>
      <div class="flex flex-col gap-1">
        {Enum.map(assigns.palette, &swatch(&1, assigns))}
      </div>
      {selected_color(assigns)}
      <div class="flex flex-col gap-2">
        <text style={[color: {:rgb, 0x94A3B8}]}>Application-side CSS path</text>
        <UI.input
          id="export-path"
          label="CSS export path"
          value={assigns.export_path}
          placeholder="palette.css"
          phx-change="export_path_changed"
        />
        <div class="flex gap-2">
          <UI.button
            id="export-palette"
            label={export_label(assigns.status)}
            variant="primary"
            disabled={not palette_interactive?(assigns) or String.trim(assigns.export_path) == ""}
            phx-click="export_palette"
          />
          <UI.copy_button
            id="copy-palette-css"
            label="Copy CSS"
            text={Analysis.css(assigns.palette)}
            disabled={not palette_interactive?(assigns)}
            phx-click="palette_copied"
          />
        </div>
        <text style={[color: status_color(assigns.status)]}>{status_text(assigns)}</text>
      </div>
    </div>
    """
  end

  defp swatch(color, palette_assigns) do
    assigns = %{
      color: color,
      selected: palette_assigns.selected == color.hex,
      disabled: not palette_interactive?(palette_assigns)
    }

    ~GPUI"""
    <div class="flex items-center gap-3">
      <div style={[width: {:px, 48}, height: {:px, 40}, background: {:rgb, color_rgb(assigns.color)}]} />
      <UI.button
        id={"color-" <> assigns.color.hex}
        label={assigns.color.hex}
        variant={if(assigns.selected, do: "primary", else: "default")}
        disabled={assigns.disabled}
        phx-click={"select_color:" <> assigns.color.hex}
      />
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.color.count} samples</text>
    </div>
    """
  end

  defp selected_color(assigns) do
    color = Enum.find(assigns.palette, &(&1.hex == assigns.selected))
    selected_assigns = %{color: color}

    ~GPUI"""
    <text style={[color: {:rgb, 0x94A3B8}]}>{selected_color_label(selected_assigns.color)}</text>
    """
  end

  defp selected_color_label(nil), do: "No color selected"

  defp selected_color_label(color),
    do: "Selected #{color.hex} · RGB #{color.red}, #{color.green}, #{color.blue}"

  defp palette_interactive?(assigns),
    do: assigns.palette != [] and assigns.status not in [:loading, :exporting]

  defp color_rgb(color), do: color.red * 65_536 + color.green * 256 + color.blue
  defp picker_label(:loading), do: "Choose replacement"
  defp picker_label(_status), do: "Choose image"
  defp source_label(%{source_name: nil}), do: "No image selected"
  defp source_label(assigns), do: assigns.source_name
  defp export_label(:exporting), do: "Exporting…"
  defp export_label(_status), do: "Export CSS"
  defp palette_empty_text(:loading), do: "Analyzing the image…"
  defp palette_empty_text(_status), do: "Load an image to generate a palette."
  defp status_color(:error), do: {:rgb, 0xFCA5A5}
  defp status_color(status) when status in [:copied, :exported], do: {:rgb, 0x86EFAC}
  defp status_color(_status), do: {:rgb, 0x94A3B8}

  defp status_text(%{error: error}) when is_binary(error), do: error
  defp status_text(%{status: :idle, stage: stage}), do: stage
  defp status_text(%{status: :ready, stage: "Analysis cancelled"}), do: "Analysis cancelled"
  defp status_text(%{status: :ready}), do: "Palette ready"
  defp status_text(%{status: :copied, stage: stage}), do: stage
  defp status_text(%{status: :exporting}), do: "Writing CSS…"
  defp status_text(%{status: :exported, stage: stage}), do: stage
  defp status_text(assigns), do: assigns.stage
end

defmodule Examples.ImagePalette.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    result = Map.get(args, :result)
    path = Map.get(args, :path, "")
    palette = if result, do: result.palette, else: []
    selected = palette |> List.first() |> then(&if(&1, do: &1.hex))
    source_name = if path == "", do: nil, else: Path.basename(path)

    {:ok,
     [
       window "Image Palette" do
         size(1000, 720)

         root(Examples.ImagePalette.View,
           path: path,
           export_path: Map.get(args, :export_path, "palette.css"),
           status: if(result, do: :ready, else: :idle),
           progress: if(result, do: 100, else: 0),
           stage: if(result, do: "Ready", else: "Choose an image to begin"),
           error: nil,
           job_id: 0,
           source_name: source_name,
           image: result && result.preview,
           image_width: result && result.width,
           image_height: result && result.height,
           palette: palette,
           selected: selected
         )
       end
     ]}
  end
end

defmodule Examples.ImagePalette.Coordinator do
  use GenServer

  alias Examples.ImagePalette.Analysis
  alias GPUI.Runtime
  alias GPUI.Runtime.Update

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    :ok = Runtime.subscribe(runtime)

    {:ok,
     %{
       runtime: runtime,
       task_supervisor: Keyword.fetch!(opts, :task_supervisor),
       read: Keyword.get(opts, :read, &File.read/1),
       decode: Keyword.get(opts, :decode, &GPUI.Image.decode/1),
       analyze: Keyword.get(opts, :analyze, &Analysis.analyze/2),
       write: Keyword.get(opts, :write, &File.write/2),
       owner: Keyword.get(opts, :owner),
       load_task: nil,
       export_task: nil
     }}
  end

  @impl GenServer
  def handle_info({:gpui, runtime, %Update{} = update}, %{runtime: runtime} = state) do
    assigns = root_assigns(update.snapshot)

    state =
      Enum.reduce(update.events, state, fn
        %{event: "load_image"}, state ->
          start_load(state, assigns)

        %{event: "image_file_selected", value: %{status: :selected, data: data}}, state ->
          start_bytes_load(state, assigns, data)

        %{event: "cancel_load"}, state ->
          cancel_load(state)

        %{event: "export_palette"}, state ->
          start_export(state, assigns)

        _event, state ->
          state
      end)

    {:noreply, state}
  end

  def handle_info({:image_progress, job_id, percent, stage}, state) do
    if active_job?(state.load_task, job_id) do
      {:ok, _snapshot} =
        Runtime.send_view(state.runtime, 1, {:image_progress, job_id, percent, stage})
    end

    {:noreply, state}
  end

  def handle_info({:image_loaded, job_id, result}, state) do
    if active_job?(state.load_task, job_id) do
      :ok =
        Runtime.put_resource(
          state.runtime,
          "image-palette-preview",
          GPUI.Raster.to_payload(result.preview)
        )

      {:ok, _snapshot} =
        Runtime.send_view(
          state.runtime,
          1,
          {:image_loaded, job_id, result.width, result.height, result.palette}
        )

      notify(state.owner, {:image_palette, :loaded, job_id})
      {:noreply, %{state | load_task: finish_task(state.load_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:image_failed, job_id, message}, state) do
    if active_job?(state.load_task, job_id) do
      {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:image_failed, job_id, message})
      notify(state.owner, {:image_palette, :failed, job_id, message})
      {:noreply, %{state | load_task: finish_task(state.load_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:palette_exported, path}, state) do
    if state.export_task do
      {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:palette_exported, path})
      notify(state.owner, {:image_palette, :exported, path})
      {:noreply, %{state | export_task: finish_task(state.export_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:palette_export_failed, message}, state) do
    if state.export_task do
      {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:palette_export_failed, message})
      notify(state.owner, {:image_palette, :export_failed, message})
      {:noreply, %{state | export_task: finish_task(state.export_task)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({ref, _result}, state) when is_reference(ref), do: {:noreply, state}

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    cond do
      task_ref(state.load_task) == ref ->
        state = %{state | load_task: nil}
        maybe_report_task_exit(state, :load, reason)
        {:noreply, state}

      task_ref(state.export_task) == ref ->
        state = %{state | export_task: nil}
        maybe_report_task_exit(state, :export, reason)
        {:noreply, state}

      true ->
        {:noreply, state}
    end
  end

  defp start_load(state, assigns) do
    state = %{state | load_task: cancel_task(state.load_task)}
    parent = self()
    job_id = assigns.job_id

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        load_image(parent, job_id, assigns.path, state)
      end)

    %{state | load_task: %{task: task, job_id: job_id}}
  end

  defp start_bytes_load(state, assigns, data) do
    state = %{state | load_task: cancel_task(state.load_task)}
    parent = self()
    job_id = assigns.job_id
    source_name = assigns.source_name

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        decode_image(parent, job_id, source_name, data, state)
      end)

    %{state | load_task: %{task: task, job_id: job_id}}
  end

  defp cancel_load(%{load_task: nil} = state), do: state

  defp cancel_load(state) do
    job_id = state.load_task.job_id
    notify(state.owner, {:image_palette, :cancelled, job_id})
    %{state | load_task: cancel_task(state.load_task)}
  end

  defp start_export(state, assigns) do
    state = %{state | export_task: cancel_task(state.export_task)}
    parent = self()
    path = assigns.export_path
    css = Analysis.css(assigns.palette)

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        case state.write.(path, css) do
          :ok -> send(parent, {:palette_exported, path})
          {:error, reason} -> send(parent, {:palette_export_failed, file_error(path, reason)})
        end
      end)

    %{state | export_task: %{task: task}}
  end

  defp load_image(parent, job_id, path, state) do
    send(parent, {:image_progress, job_id, 10, "Reading file"})

    case state.read.(path) do
      {:ok, bytes} -> decode_image(parent, job_id, path, bytes, state)
      {:error, reason} -> send(parent, {:image_failed, job_id, load_error(path, reason)})
    end
  rescue
    error -> send(parent, {:image_failed, job_id, Exception.message(error)})
  end

  defp decode_image(parent, job_id, source_name, bytes, state) do
    send(parent, {:image_progress, job_id, 25, "Decoding image"})

    result =
      with {:ok, raster} <- state.decode.(bytes) do
        progress = fn percent, stage ->
          send(parent, {:image_progress, job_id, percent, stage})
        end

        {:ok, state.analyze.(raster, progress: progress)}
      end

    case result do
      {:ok, analysis} -> send(parent, {:image_loaded, job_id, analysis})
      {:error, reason} -> send(parent, {:image_failed, job_id, load_error(source_name, reason)})
    end
  rescue
    error -> send(parent, {:image_failed, job_id, Exception.message(error)})
  end

  defp root_assigns(%GPUI.Snapshot{windows: [%{root: %{assigns: assigns}} | _windows]}),
    do: assigns

  defp active_job?(%{job_id: job_id}, job_id), do: true
  defp active_job?(_task, _job_id), do: false
  defp task_ref(%{task: %Task{ref: ref}}), do: ref
  defp task_ref(_task), do: nil

  defp finish_task(%{task: %Task{ref: ref}}) do
    Process.demonitor(ref, [:flush])
    nil
  end

  defp cancel_task(nil), do: nil

  defp cancel_task(%{task: task}) do
    _result = Task.shutdown(task, :brutal_kill)
    nil
  end

  defp maybe_report_task_exit(_state, _kind, :normal), do: :ok

  defp maybe_report_task_exit(state, kind, reason),
    do: notify(state.owner, {:image_palette, :task_exit, kind, reason})

  defp load_error(path, :invalid_image), do: "#{path} is not a supported image"
  defp load_error(path, reason), do: file_error(path, reason)
  defp file_error(path, reason), do: "#{path}: #{:file.format_error(reason)}"
  defp notify(nil, _message), do: :ok
  defp notify(owner, message), do: send(owner, message)
end

defmodule Examples.ImagePalette.Supervisor do
  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  @impl Supervisor
  def init(opts) do
    task_supervisor =
      Keyword.get(opts, :task_supervisor, Examples.ImagePalette.TaskSupervisor)

    coordinator_opts =
      opts
      |> Keyword.put(:task_supervisor, task_supervisor)
      |> Keyword.delete(:name)

    children = [
      {Task.Supervisor, name: task_supervisor},
      {Examples.ImagePalette.Coordinator, coordinator_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
