defmodule GPUI.Runtime do
  @moduledoc """
  OTP owner for a GPUI backend.

  This first slice keeps the backend in Elixir data so the DSL and supervision
  contract can stabilize before the Rust Port host is wired in.
  """

  use GenServer

  alias GPUI.WindowSpec

  @type state :: %{
          app: module(),
          app_state: term(),
          windows: [WindowSpec.t()],
          host: port() | nil,
          native: term() | nil,
          host_messages: [map()]
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    app = Keyword.fetch!(opts, :app)
    GenServer.start_link(__MODULE__, opts, name: app)
  end

  @impl GenServer
  def init(opts) do
    app = Keyword.fetch!(opts, :app)
    args = Keyword.get(opts, :args, [])

    host = start_host(opts)
    native = start_native(opts)

    case app.mount(args) do
      {:ok, app_state} ->
        {:ok,
         %{
           app: app,
           app_state: app_state,
           windows: [],
           host: host,
           native: native,
           host_messages: []
         }}

      {:ok, app_state, windows} when is_list(windows) ->
        Enum.each(windows, &sync_window(host, native, &1))

        {:ok,
         %{
           app: app,
           app_state: app_state,
           windows: windows,
           host: host,
           native: native,
           host_messages: []
         }}
    end
  end

  @doc "Returns declared windows for tests and future backend synchronization."
  @spec windows(GenServer.server()) :: [WindowSpec.t()]
  def windows(server), do: GenServer.call(server, :windows)

  @doc "Returns replies/events received from the Rust host."
  @spec host_messages(GenServer.server()) :: [map()]
  def host_messages(server), do: GenServer.call(server, :host_messages)

  @impl GenServer
  def handle_call(:windows, _from, state) do
    {:reply, state.windows, state}
  end

  @impl GenServer
  def handle_call(:host_messages, _from, %{native: nil} = state) do
    {:reply, Enum.reverse(state.host_messages), state}
  end

  def handle_call(:host_messages, _from, %{native: native} = state) do
    {:ok, events} = GPUI.Native.drain_events(native)
    native_messages = Enum.map(events, &%{op: :native_event, payload: &1})
    {:reply, Enum.reverse(state.host_messages) ++ native_messages, state}
  end

  @impl GenServer
  def handle_info({host, {:data, payload}}, %{host: host} = state) do
    message = GPUI.Protocol.decode(payload)
    {:noreply, %{state | host_messages: [message | state.host_messages]}}
  end

  @impl GenServer
  def handle_info({host, {:exit_status, status}}, %{host: host} = state) do
    message = %{op: :host_exit, status: status}
    {:noreply, %{state | host: nil, host_messages: [message | state.host_messages]}}
  end

  defp start_host(opts) do
    case Keyword.get(opts, :backend, :data) do
      :host -> GPUI.Host.start_link(opts)
      _backend -> nil
    end
  end

  defp start_native(opts) do
    case Keyword.get(opts, :backend, :data) do
      :native ->
        {:ok, runtime} = GPUI.Native.start_runtime()
        runtime

      _backend ->
        nil
    end
  end

  defp sync_window(nil, nil, %WindowSpec{}), do: :ok

  defp sync_window(host, nil, %WindowSpec{} = window) when is_port(host) do
    GPUI.Host.command(host, GPUI.Protocol.command(:open_window, window_payload(window)))
  end

  defp sync_window(nil, native, %WindowSpec{} = window) do
    {:ok, _title} = GPUI.Native.open_window(native, window_payload(window))
    :ok
  end

  defp window_payload(%WindowSpec{} = window) do
    %{
      title: window.title,
      size: Tuple.to_list(window.size || {800, 600}),
      root: encode_root(window.root)
    }
  end

  defp encode_root(nil), do: nil
  defp encode_root({module, assigns}), do: %{module: inspect(module), assigns: Map.new(assigns)}
end
