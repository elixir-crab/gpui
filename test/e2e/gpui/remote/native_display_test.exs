defmodule GPUI.Remote.NativeDisplayE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  defmodule CounterView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-center justify-center bg-slate-900 text-white text-2xl p-4 gap-2">
        <text>Count: {assigns.count}</text>
        <button phx-click="inc" class="bg-blue-600 text-white text-xl p-2 rounded-md">
          +
        </button>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("inc", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}
  end

  defmodule CounterApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote E2E" do
           size(320, 240)
           root(CounterView, count: 0)
         end
       ]}
    end
  end

  test "a TCP session renders through the real native display" do
    port = available_port()
    {:ok, server} = GPUI.Remote.Server.start_link(app: CounterApp, port: port)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Display.Native,
        poll_interval: 10
      )

    on_exit(fn -> Desktop.stop_process(client) end)
    on_exit(fn -> Desktop.stop_process(server) end)

    assert {:ok, %{windows: [window]}} = GPUI.Remote.Client.mount(client)
    assert 0 = get_in(window, [:root, :assigns, :count])

    assert {:ok, %{windows: [updated]}} =
             GPUI.Remote.Client.event(client, %{window_id: window.id, event: "inc"})

    assert 1 = get_in(updated, [:root, :assigns, :count])
  end

  defp available_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_address, port}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
