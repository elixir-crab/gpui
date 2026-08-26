defmodule GPUI.Runtime.EventLoopTest do
  use ExUnit.Case, async: true

  defmodule CounterView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-center gap-3">
        <text class="text-xl">Count: {assigns.count}</text>
        <button phx-click="inc">+</button>
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
      {:ok, [window("Counter", do: root(CounterView, count: 0))]}
    end
  end

  test "display events update session state and synchronize a new snapshot" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: CounterApp,
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, %{windows: [%{id: 1}]}}

    assert {:ok, :ok} =
             GPUI.Runtime.inject_event(runtime, %{type: :click, window_id: 1, event: "inc"})

    assert [%{type: :click, event: "inc", window_id: 1}] = GPUI.Runtime.drain_events(runtime)
    assert [%{type: :click, event: "inc", window_id: 1}] = GPUI.Runtime.events(runtime)

    assert %{windows: [%{root: %{assigns: %{count: 1}}}]} = GPUI.Runtime.snapshot(runtime)
    assert_receive {:gpui_snapshot, %{windows: [%{root: %{assigns: %{count: 1}}}]}}
  end

  test "native window closure removes the window from its session" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: CounterApp,
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, %{windows: [%{id: 1}]}}

    assert {:ok, :ok} =
             GPUI.Runtime.inject_event(runtime, %{type: :window_closed, window_id: 1})

    assert [%{type: :window_closed, window_id: 1}] = GPUI.Runtime.drain_events(runtime)
    assert %{windows: []} = GPUI.Runtime.snapshot(runtime)
    assert_receive {:gpui_snapshot, %{windows: []}}
  end

  test "resources belong to the session snapshot and are synchronized to the display" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: CounterApp, display: GPUI.Test.Display, poll_interval: nil)

    raster = %{__type__: :raster, width: 1, height: 1, format: :rgba8, data: <<255, 0, 0, 255>>}

    assert :ok = GPUI.Runtime.put_resource(runtime, "logo", raster)
    assert %{resources: %{"logo" => ^raster}} = GPUI.Runtime.snapshot(runtime)

    assert :ok = GPUI.Runtime.drop_resource(runtime, "logo")
    assert %{resources: %{}} = GPUI.Runtime.snapshot(runtime)
  end

  test "rejects invalid polling intervals during startup" do
    assert {:error, {:invalid_option, :poll_interval}} =
             GPUI.Runtime.start_link(
               app: CounterApp,
               display: GPUI.Test.Display,
               poll_interval: 0
             )

    assert {:error, {:invalid_option, :poll_interval}} =
             GPUI.Runtime.start_link(
               app: CounterApp,
               display: GPUI.Test.Display,
               poll_interval: :fast
             )
  end

  test "display events can be polled automatically" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: CounterApp,
        display: GPUI.Test.Display,
        poll_interval: 10
      )

    :ok = GPUI.Runtime.subscribe(runtime)

    {:ok, :ok} =
      GPUI.Runtime.inject_event(runtime, %{type: :click, window_id: 1, event: "inc"})

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [%{type: :click, event: "inc", window_id: 1}],
                      snapshot: %{windows: [%{root: %{assigns: %{count: 1}}}]}
                    }}

    assert %{type: :click, event: "inc", window_id: 1} in GPUI.Runtime.events(runtime)
  end
end
