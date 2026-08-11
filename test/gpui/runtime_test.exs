defmodule GPUI.RuntimeTest do
  use ExUnit.Case, async: true

  defmodule HelloView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-center bg-neutral-700">
        <text>Hello {assigns.name}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("rename", %{value: name}, assigns),
      do: {:noreply, %{assigns | name: name}}

    @impl GPUI.View
    def handle_info({:rename, name}, assigns),
      do: {:noreply, %{assigns | name: name}}
  end

  defmodule DemoApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI + Elixir" do
           size(500, 500)
           root(HelloView, name: "OTP")
         end
       ]}
    end
  end

  defmodule SecondaryView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns), do: %GPUI.Element{type: :text, children: [assigns.label]}
  end

  defmodule ClosingView do
    use GPUI.View

    @impl GPUI.View
    def render(_assigns), do: %GPUI.Element{type: :div}

    @impl GPUI.View
    def handle_event("confirm-close", _event, assigns), do: {:close, assigns}
  end

  defmodule ClosingApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Closing" do
           root(ClosingView)
         end
       ]}
    end
  end

  defmodule RecordingDisplay do
    @behaviour GPUI.Display

    use Agent

    @impl GPUI.Display
    def start_link(_opts), do: Agent.start_link(fn -> [] end)

    @impl GPUI.Display
    def sync(display, snapshot) do
      Agent.update(display, &[snapshot | &1])
      :ok
    end

    @impl GPUI.Display
    def drain_events(_display), do: {:ok, []}

    @impl GPUI.Display
    def inject_event(_display, _event), do: {:ok, :ok}
  end

  defmodule RefreshView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns), do: %GPUI.Element{type: :text, children: [renderer().(assigns)]}

    defp renderer do
      :persistent_term.get({__MODULE__, :renderer}, fn assigns -> "before #{assigns.name}" end)
    end
  end

  defmodule RefreshApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Refresh" do
           root(RefreshView, name: "preserved")
         end
       ]}
    end
  end

  defmodule EmptyApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args), do: {:ok, []}
  end

  defmodule InvalidMountApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args), do: :invalid
  end

  defmodule ContractDisplay do
    @behaviour GPUI.Display

    use Agent

    @impl GPUI.Display
    def start_link(opts) do
      case Keyword.fetch!(opts, :mode) do
        :raise_start -> raise "start failed"
        :invalid_start -> :invalid_start
        mode -> Agent.start_link(fn -> mode end)
      end
    end

    @impl GPUI.Display
    def sync(display, _snapshot) do
      case Agent.get(display, & &1) do
        :raise_sync -> raise "sync failed"
        :invalid_sync -> :invalid_sync
        _mode -> :ok
      end
    end

    @impl GPUI.Display
    def drain_events(display) do
      case Agent.get(display, & &1) do
        :raise_drain -> raise "drain failed"
        :invalid_drain -> :invalid_drain
        _mode -> {:ok, []}
      end
    end

    @impl GPUI.Display
    def inject_event(display, _event) do
      case Agent.get(display, & &1) do
        :raise_inject -> raise "inject failed"
        :invalid_inject -> :invalid_inject
        _mode -> {:ok, :ok}
      end
    end
  end

  defmodule RaisingFrameDisplay do
    @behaviour GPUI.Display

    use Agent

    @impl GPUI.Display
    def start_link(_opts), do: Agent.start_link(fn -> nil end)

    @impl GPUI.Display
    def sync(_display, _snapshot), do: :ok

    @impl GPUI.Display
    def drain_events(_display), do: {:ok, []}

    @impl GPUI.Display
    def inject_event(_display, _event), do: {:ok, :ok}

    @impl GPUI.Display
    def await_frame(_display, _window_id, _timeout), do: raise("frame failed")
  end

  defmodule BlockingFrameDisplay do
    @behaviour GPUI.Display

    use Agent

    @impl GPUI.Display
    def start_link(opts), do: Agent.start_link(fn -> Keyword.fetch!(opts, :owner) end)

    @impl GPUI.Display
    def sync(_display, _snapshot), do: :ok

    @impl GPUI.Display
    def drain_events(_display), do: {:ok, []}

    @impl GPUI.Display
    def inject_event(_display, _event), do: {:ok, :ok}

    @impl GPUI.Display
    def await_frame(display, _window_id, _timeout) do
      owner = Agent.get(display, & &1)
      send(owner, {:frame_waiting, self()})

      receive do
        :release_frame -> :ok
      end
    end
  end

  test "runtime reconciles dynamically added and removed keyed windows" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: DemoApp,
        display: RecordingDisplay,
        poll_interval: nil
      )

    secondary = %GPUI.WindowSpec{
      key: "details",
      title: "Details",
      root: {SecondaryView, %{label: "Secondary"}}
    }

    assert {:ok, 2, %{windows: [primary, added]}} = GPUI.Runtime.open_window(runtime, secondary)
    assert primary.id == 1
    assert added.id == 2
    assert added.key == "details"
    assert added.root.assigns.label == "Secondary"

    assert {:error, :duplicate_window_key} = GPUI.Runtime.open_window(runtime, secondary)

    assert {:ok, %{windows: [remaining]}} = GPUI.Runtime.close_window(runtime, "details")
    assert remaining.id == 1

    assert {:ok, 3, %{windows: [_primary, reopened]}} =
             GPUI.Runtime.open_window(runtime, %{secondary | title: "Reopened"})

    assert reopened.id == 3
    assert reopened.key == "details"
    assert {:ok, %{windows: [^reopened]}} = GPUI.Runtime.close_window(runtime, 1)
    assert {:ok, %{windows: []}} = GPUI.Runtime.close_window(runtime, "details")
    assert {:error, :window_not_found} = GPUI.Runtime.close_window(runtime, "missing")
  end

  test "close event outcomes synchronize removed windows to the display" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: ClosingApp,
        display: RecordingDisplay,
        poll_interval: nil
      )

    %{display: display} = :sys.get_state(runtime)
    assert [%{windows: [_window]}] = Agent.get(display, & &1)

    {_event, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "confirm-close"
      })

    assert snapshot.windows == []
    assert [%{windows: []}, %{windows: [_window]}] = Agent.get(display, & &1)
  end

  test "runtime startup normalizes custom display failures" do
    previous = Process.flag(:trap_exit, true)

    assert {:error,
            {:display_start_failed,
             {:display_callback_failed, :start_link, :error,
              %RuntimeError{message: "start failed"}}}} =
             GPUI.Runtime.start_link(
               app: DemoApp,
               display: ContractDisplay,
               display_opts: [mode: :raise_start]
             )

    assert {:error,
            {:display_start_failed, {:invalid_display_return, :start_link, :invalid_start}}} =
             GPUI.Runtime.start_link(
               app: DemoApp,
               display: ContractDisplay,
               display_opts: [mode: :invalid_start]
             )

    assert {:error, {:display_sync_failed, {:invalid_display_return, :sync, :invalid_sync}}} =
             GPUI.Runtime.start_link(
               app: DemoApp,
               display: ContractDisplay,
               display_opts: [mode: :invalid_sync]
             )

    assert {:error,
            {:display_sync_failed,
             {:display_callback_failed, :sync, :error, %RuntimeError{message: "sync failed"}}}} =
             GPUI.Runtime.start_link(
               app: DemoApp,
               display: ContractDisplay,
               display_opts: [mode: :raise_sync]
             )

    Process.flag(:trap_exit, previous)
  end

  test "runtime operations return display failures without crashing" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: DemoApp,
        display: ContractDisplay,
        display_opts: [mode: :ok],
        poll_interval: nil
      )

    %{display: display} = :sys.get_state(runtime)
    set_display_mode(display, :invalid_sync)

    assert {:error, {:display_sync_failed, {:invalid_display_return, :sync, :invalid_sync}}} =
             GPUI.Runtime.dispatch_event(runtime, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "Changed"
             })

    assert {:error, {:display_sync_failed, {:invalid_display_return, :sync, :invalid_sync}}} =
             GPUI.Runtime.send_view(runtime, 1, {:rename, "Message"})

    assert {:error, {:display_sync_failed, {:invalid_display_return, :sync, :invalid_sync}}} =
             GPUI.Runtime.put_resource(runtime, "preview", %{})

    assert {:error, {:display_sync_failed, {:invalid_display_return, :sync, :invalid_sync}}} =
             GPUI.Runtime.refresh(runtime)

    assert {:error, {:display_sync_failed, {:invalid_display_return, :sync, :invalid_sync}}} =
             GPUI.Runtime.request_frame(runtime)

    set_display_mode(display, :invalid_inject)

    assert {:error,
            {:display_inject_failed, {:invalid_display_return, :inject_event, :invalid_inject}}} =
             GPUI.Runtime.inject_event(runtime, %{type: :click})

    set_display_mode(display, :invalid_drain)

    assert {:error,
            {:display_drain_failed, {:invalid_display_return, :drain_events, :invalid_drain}}} =
             GPUI.Runtime.drain_events(runtime)

    assert Process.alive?(runtime)
  end

  test "display boundary normalizes event callback failures" do
    {:ok, invalid_drain} = ContractDisplay.start_link(mode: :invalid_drain)
    {:ok, raising_drain} = ContractDisplay.start_link(mode: :raise_drain)
    {:ok, invalid_inject} = ContractDisplay.start_link(mode: :invalid_inject)
    {:ok, raising_inject} = ContractDisplay.start_link(mode: :raise_inject)

    assert {:error, {:invalid_display_return, :drain_events, :invalid_drain}} =
             GPUI.Display.drain(ContractDisplay, invalid_drain)

    assert {:error,
            {:display_callback_failed, :drain_events, :error,
             %RuntimeError{message: "drain failed"}}} =
             GPUI.Display.drain(ContractDisplay, raising_drain)

    assert {:error, {:invalid_display_return, :inject_event, :invalid_inject}} =
             GPUI.Display.inject(ContractDisplay, invalid_inject, %{})

    assert {:error,
            {:display_callback_failed, :inject_event, :error,
             %RuntimeError{message: "inject failed"}}} =
             GPUI.Display.inject(ContractDisplay, raising_inject, %{})
  end

  test "application modules start renderer-independent sessions with a display" do
    {:ok, runtime} =
      start_supervised({DemoApp, display: GPUI.Test.Display, display_opts: [owner: self()]})

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir", size: {500, 500}}] =
             GPUI.Runtime.windows(runtime)

    assert_receive {:gpui_snapshot, %{windows: [%{id: 1}]}}
  end

  test "runtime snapshots contain rendered window trees" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: GPUI.Test.Display)

    assert %{
             windows: [
               %{
                 root: %{
                   module: module,
                   assigns: %{name: "OTP"},
                   tree: %{
                     type: :viewport,
                     attrs: %{},
                     children: [
                       %{
                         type: :div,
                         attrs: %{
                           style: [
                             display: :flex,
                             flex_direction: :column,
                             align_items: :center,
                             background: [:rgb, 4_210_752]
                           ]
                         },
                         children: [%{type: :text, children: ["Hello ", "OTP"]}]
                       }
                     ]
                   }
                 }
               }
             ],
             resources: %{}
           } = GPUI.Runtime.snapshot(runtime)

    assert module =~ "HelloView"
  end

  test "runtime subscriptions deliver synchronized typed updates" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: GPUI.Test.Display)

    assert :ok = GPUI.Runtime.subscribe(runtime)

    {_handled, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :change,
        window_id: 1,
        event: "rename",
        value: "BEAM"
      })

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      revision: 1,
                      events: [%{event: "rename"}],
                      snapshot: ^snapshot
                    }}

    assert :ok = GPUI.Runtime.unsubscribe(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :change,
      window_id: 1,
      event: "rename",
      value: "OTP"
    })

    refute_receive {:gpui, ^runtime, %GPUI.Runtime.Update{}}
  end

  test "runtime removes subscribers when their processes exit" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: GPUI.Test.Display)

    owner = self()

    subscriber =
      spawn(fn ->
        :ok = GPUI.Runtime.subscribe(runtime)
        send(owner, {:subscribed, self()})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:subscribed, ^subscriber}
    %{subscribers: %{^subscriber => monitor}} = :sys.get_state(runtime)
    :erlang.trace(runtime, true, [:receive])
    Process.exit(subscriber, :kill)

    assert_receive {:trace, ^runtime, :receive, {:DOWN, ^monitor, :process, ^subscriber, :killed}}
    refute Map.has_key?(:sys.get_state(runtime).subscribers, subscriber)
    :erlang.trace(runtime, false, [:receive])
  end

  test "OTP messages update root views and synchronize displays" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: DemoApp,
        display: GPUI.Test.Display,
        display_opts: [owner: self()]
      )

    assert_receive {:gpui_snapshot, %{windows: [%{root: %{assigns: %{name: "OTP"}}}]}}
    assert :ok = GPUI.Runtime.subscribe(runtime)

    assert {:ok, %{windows: [%{root: %{assigns: %{name: "BEAM"}}}]} = snapshot} =
             GPUI.Runtime.send_view(runtime, 1, {:rename, "BEAM"})

    assert_receive {:gpui_snapshot, ^snapshot}

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{revision: 1, events: [], snapshot: ^snapshot}}

    assert {:error, :window_not_found} = GPUI.Runtime.send_view(runtime, 999, :ignored)
  end

  test "refresh rerenders current assigns and synchronizes subscribers" do
    :persistent_term.put(
      {RefreshView, :renderer},
      fn assigns -> "before #{assigns.name}" end
    )

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: RefreshApp,
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, %{windows: [%{root: %{tree: before_tree}}]}}
    assert get_in(before_tree, [:children, Access.at(0), :children]) == ["before preserved"]
    assert :ok = GPUI.Runtime.subscribe(runtime)

    :persistent_term.put(
      {RefreshView, :renderer},
      fn assigns -> "after #{assigns.name}" end
    )

    assert {:ok,
            %{windows: [%{root: %{assigns: %{name: "preserved"}, tree: after_tree}}]} =
              snapshot} = GPUI.Runtime.refresh(runtime)

    assert get_in(after_tree, [:children, Access.at(0), :children]) == ["after preserved"]
    assert_receive {:gpui_snapshot, ^snapshot}

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{revision: 1, events: [], snapshot: ^snapshot}}
  after
    :persistent_term.erase({RefreshView, :renderer})
  end

  test "runtime frame barriers delegate to the active display" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: GPUI.Test.Display)

    assert :ok = GPUI.Runtime.await_frame(runtime, 1)
    assert {:ok, 0} = GPUI.Runtime.frame_token(runtime, 1)
    assert :ok = GPUI.Runtime.await_frame_after(runtime, 1, 0)
    assert {:error, :window_not_found} = GPUI.Runtime.await_frame(runtime, 999)
    assert {:error, :window_not_found} = GPUI.Runtime.frame_token(runtime, 999)
    assert {:error, :window_not_found} = GPUI.Runtime.await_frame_after(runtime, 999, 0)
  end

  test "display callback failures reply without blocking or crashing the runtime" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: RaisingFrameDisplay)

    assert {:error, {:display_callback_failed, :error, %RuntimeError{message: "frame failed"}}} =
             GPUI.Runtime.await_frame(runtime, 1)

    assert Process.alive?(runtime)
  end

  test "waiting for a frame does not block the runtime" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: DemoApp,
        display: BlockingFrameDisplay,
        display_opts: [owner: self()]
      )

    waiter = Task.async(fn -> GPUI.Runtime.await_frame(runtime, 1) end)
    assert_receive {:frame_waiting, frame_task}
    assert [%GPUI.WindowSpec{id: 1}] = GPUI.Runtime.windows(runtime)

    send(frame_task, :release_frame)
    assert :ok = Task.await(waiter)
  end

  test "sessions reject invalid application mount results explicitly" do
    previous = Process.flag(:trap_exit, true)

    assert {:error, {:invalid_mount_return, :invalid}} =
             GPUI.Session.start_link(app: InvalidMountApp)

    Process.flag(:trap_exit, previous)
  end

  test "applications can mount an empty window set without placeholder state" do
    {:ok, session} = GPUI.Session.start_link(app: EmptyApp)

    assert [] = GPUI.Session.windows(session)
    assert %GPUI.Snapshot{windows: [], resources: %{}} = GPUI.Session.snapshot(session)
  end

  defp set_display_mode(display, mode), do: Agent.update(display, fn _current -> mode end)

  test "sessions can run without any display" do
    {:ok, session} = GPUI.Session.start_link(app: DemoApp)

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir"}] = GPUI.Session.windows(session)
    assert %{windows: [%{id: 1}], resources: %{}} = GPUI.Session.snapshot(session)
  end
end
