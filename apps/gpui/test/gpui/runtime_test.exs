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

  test "local view callbacks receive canonical public transfer events" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: TransferApp, display: RecordingDisplay, poll_interval: nil)

    {:ok, _handled, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :drop,
        window_id: 1,
        event: "files-dropped",
        value: %{
          session_id: 17,
          target_id: "attachments",
          x: 320.0,
          y: 180.0,
          coordinate_space: "window_native_pixels",
          payload: %{text: nil, external_paths: ["/display/tmp/document.pdf"]}
        }
      })

    assert %GPUI.Transfer.Event{
             session_id: 17,
             target_id: "attachments",
             position: {320.0, 180.0},
             coordinate_space: :window_native_pixels,
             payload: %GPUI.Transfer.Payload{
               text: nil,
               external_paths: ["/display/tmp/document.pdf"]
             }
           } = snapshot.windows |> hd() |> get_in([:root, :assigns, :status])
  end

  test "dispatches typed rich link events through the ordinary view callback" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: DemoApp, display: RecordingDisplay, poll_interval: nil)

    {:ok, handled, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :link,
        window_id: 1,
        event: "open-link",
        value: "message://details"
      })

    assert handled.type == :link
    assert %{windows: [%{root: %{assigns: %{name: "message://details"}}}]} = snapshot
  end

  test "typed view outcomes mutate window topology atomically" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: OutcomeApp, display: RecordingDisplay, poll_interval: nil)

    {:ok, handled, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "open-details"
      })

    refute Map.has_key?(handled, :error)
    assert [%{root: %{assigns: %{label: "Details opened"}}}, %{key: "details"}] = snapshot.windows

    {:ok, handled, unchanged} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "open-details"
      })

    assert handled.error == :duplicate_window_key
    assert unchanged == snapshot

    {:ok, _handled, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "close-details"
      })

    assert [%{root: %{assigns: %{label: "Details closed"}}}] = snapshot.windows

    assert {:ok, %{windows: [_, %{id: 3, key: "details"}]}} =
             GPUI.Runtime.send_view(runtime, 1, :open_details)
  end

  test "failed callback overflow preserves originating assigns" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(app: OutcomeApp, display: RecordingDisplay, poll_interval: nil)

    Enum.each(1..31, fn index ->
      assert {:ok, _, _} =
               GPUI.Runtime.open_window(runtime, %GPUI.WindowSpec{
                 key: "full-#{index}",
                 title: "Full #{index}",
                 root: {SecondaryView, %{label: "Full"}}
               })
    end)

    {:ok, handled, snapshot} =
      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "overflow"
      })

    assert handled.error == :window_limit_reached
    assert Enum.count_until(snapshot.windows, 33) == 32
    assert hd(snapshot.windows).root.assigns.label == "Main"
    refute Enum.any?(snapshot.windows, &(&1.key == "overflow"))
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

    Enum.each(1..30, fn index ->
      assert {:ok, _, _} =
               GPUI.Runtime.open_window(runtime, %{
                 secondary
                 | key: "extra-#{index}",
                   title: "Extra #{index}"
               })
    end)

    assert {:error, :window_limit_reached} =
             GPUI.Runtime.open_window(runtime, %{secondary | key: "overflow"})

    Enum.each(1..30, fn index ->
      assert {:ok, _} = GPUI.Runtime.close_window(runtime, "extra-#{index}")
    end)

    assert {:ok, %{windows: [remaining]}} = GPUI.Runtime.close_window(runtime, "details")
    assert remaining.id == 1

    assert {:ok, 33, %{windows: [_primary, reopened]}} =
             GPUI.Runtime.open_window(runtime, %{secondary | title: "Reopened"})

    assert reopened.id == 33
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

    {:ok, _event, snapshot} =
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

  test "runtime retries authoritative snapshots after a display sync failure" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: DemoApp,
        display: RecoveringDisplay,
        poll_interval: 10
      )

    %{display: display} = :sys.get_state(runtime)
    Agent.update(display, &%{&1 | failures: 1})

    assert {:error, {:display_sync_failed, :temporary}} =
             GPUI.Runtime.dispatch_event(runtime, %{
               type: :change,
               window_id: 1,
               event: "rename",
               value: "Recovered"
             })

    assert %{windows: [%{root: %{assigns: %{name: "Recovered"}}}]} =
             GPUI.Runtime.snapshot(runtime)

    Process.sleep(30)

    assert [
             %{windows: [%{root: %{assigns: %{name: "Recovered"}}}]} | _
           ] = Agent.get(display, & &1.snapshots)

    refute :sys.get_state(runtime).unsynchronized?
  end

  defp set_display_mode(display, mode), do: Agent.update(display, fn _current -> mode end)
end
