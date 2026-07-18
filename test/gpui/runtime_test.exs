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

  test "sessions can run without any display" do
    {:ok, session} = GPUI.Session.start_link(app: DemoApp)

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir"}] = GPUI.Session.windows(session)
    assert %{windows: [%{id: 1}], resources: %{}} = GPUI.Session.snapshot(session)
  end
end
