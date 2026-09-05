defmodule GPUI.Runtime.LifecycleTest do
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

    def handle_event("open-link", %{type: :link, value: link}, assigns),
      do: {:noreply, %{assigns | name: link}}

    @impl GPUI.View
    def handle_info({:rename, name}, assigns),
      do: {:noreply, %{assigns | name: name}}
  end

  defmodule IdentifiedApp do
    use GPUI.Application

    @impl GPUI.Application
    def identity do
      GPUI.Application.Identity.new!(
        id: "dev.gpui.identified",
        name: "Identified GPUI",
        icon: GPUI.Application.Icon.new!(source: "priv/branding/identified")
      )
    end

    @impl GPUI.Application
    def mount(_args) do
      {:ok, [window("Identity", do: root(HelloView, name: "Identity"))]}
    end
  end

  test "exposes stable application identity and runtime topology" do
    runtime =
      start_supervised!(
        {GPUI.Runtime, app: IdentifiedApp, display: GPUI.Test.Display, poll_interval: nil}
      )

    assert %{
             application: IdentifiedApp,
             identity: %GPUI.Application.Identity{id: "dev.gpui.identified"},
             display: GPUI.Test.Display,
             windows: 1,
             revision: 0,
             synchronized?: true
           } = GPUI.Runtime.info(runtime)
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

  defmodule TransferView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns), do: %GPUI.Element{type: :text, children: [inspect(assigns.status)]}

    @impl GPUI.View
    def handle_event("files-dropped", %{value: %GPUI.Transfer.Event{} = value}, assigns),
      do: {:noreply, %{assigns | status: value}}
  end

  defmodule TransferApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, [window("Transfer", do: root(TransferView, status: :waiting))]}
    end
  end

  defmodule SecondaryView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns), do: %GPUI.Element{type: :text, children: [assigns.label]}
  end

  defmodule OutcomeView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns), do: %GPUI.Element{type: :text, children: [assigns.label]}

    @impl GPUI.View
    def handle_event("open-details", _event, assigns) do
      details = %GPUI.WindowSpec{
        key: "details",
        title: "Details",
        root: {SecondaryView, %{label: "Opened by view"}}
      }

      {:open_window, details, %{assigns | label: "Details opened"}}
    end

    def handle_event("overflow", _event, assigns) do
      overflow = %GPUI.WindowSpec{
        key: "overflow",
        title: "Overflow",
        root: {SecondaryView, %{label: "Overflow"}}
      }

      {:open_window, overflow, %{assigns | label: "must not apply"}}
    end

    def handle_event("close-details", _event, assigns),
      do: {:close_window, "details", %{assigns | label: "Details closed"}}

    @impl GPUI.View
    def handle_info(:open_details, assigns) do
      details = %GPUI.WindowSpec{
        key: "details",
        title: "Details",
        root: {SecondaryView, %{label: "Opened by message"}}
      }

      {:open_window, details, assigns}
    end
  end

  defmodule OutcomeApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "main", "Outcomes" do
           root(OutcomeView, label: "Main")
         end
       ]}
    end
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

  defmodule RecoveringDisplay do
    @behaviour GPUI.Display

    use Agent

    @impl GPUI.Display
    def start_link(_opts), do: Agent.start_link(fn -> %{failures: 0, snapshots: []} end)

    @impl GPUI.Display
    def sync(display, snapshot) do
      Agent.get_and_update(display, fn
        %{failures: failures} = state when failures > 0 ->
          {{:error, :temporary}, %{state | failures: failures - 1}}

        state ->
          {:ok, %{state | snapshots: [snapshot | state.snapshots]}}
      end)
    end

    @impl GPUI.Display
    def drain_events(_display), do: {:ok, []}

    @impl GPUI.Display
    def inject_event(_display, _event), do: {:ok, :ok}
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

  test "display boundary normalizes event callback failures" do
    {:ok, invalid_drain} = ContractDisplay.start_link(mode: :invalid_drain)
    {:ok, raising_drain} = ContractDisplay.start_link(mode: :raise_drain)
    {:ok, invalid_inject} = ContractDisplay.start_link(mode: :invalid_inject)
    {:ok, raising_inject} = ContractDisplay.start_link(mode: :raise_inject)

    assert {:error, {:invalid_display_return, :drain_events, :invalid_drain}} =
             GPUI.Display.Support.drain(ContractDisplay, invalid_drain)

    assert {:error,
            {:display_callback_failed, :drain_events, :error,
             %RuntimeError{message: "drain failed"}}} =
             GPUI.Display.Support.drain(ContractDisplay, raising_drain)

    assert {:error, {:invalid_display_return, :inject_event, :invalid_inject}} =
             GPUI.Display.Support.inject(ContractDisplay, invalid_inject, %{})

    assert {:error,
            {:display_callback_failed, :inject_event, :error,
             %RuntimeError{message: "inject failed"}}} =
             GPUI.Display.Support.inject(ContractDisplay, raising_inject, %{})
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

    {:ok, _handled, snapshot} =
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

  test "sessions report malformed and unsupported events explicitly without dispatching them" do
    {:ok, session} = GPUI.Session.start_link(app: DemoApp)

    assert {:ok, %{window_id: 1, event: "rename", error: {:invalid_event, :type}}, snapshot} =
             GPUI.Session.dispatch_event(session, %{window_id: 1, event: "rename"})

    assert snapshot.windows |> hd() |> get_in([:root, :assigns, :name]) == "OTP"

    assert {:ok, %{type: :mystery, error: {:unsupported_event_type, :mystery}}, _snapshot} =
             GPUI.Session.dispatch_event(session, %{type: :mystery, window_id: 1})
  end

  test "sessions can run without any display" do
    {:ok, session} = GPUI.Session.start_link(app: DemoApp)

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir"}] = GPUI.Session.windows(session)
    assert %{windows: [%{id: 1}], resources: %{}} = GPUI.Session.snapshot(session)
  end
end
