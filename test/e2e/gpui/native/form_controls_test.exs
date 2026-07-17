defmodule GPUI.Native.FormControlsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule FormView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[180px] p-4 gap-4 bg-slate-900">
        <GPUI.UI.switch
          id="form-notifications"
          label="Notifications"
          checked={assigns.notifications}
          loading={assigns.switch_loading}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="form-plan"
          value={assigns.plan}
          options={assigns.plan_options}
          orientation="horizontal"
          phx-change="plan_changed"
        />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("notifications_changed", %{value: notifications}, assigns),
      do: {:noreply, %{assigns | notifications: notifications}}

    def handle_event("load_switch", _event, assigns),
      do: {:noreply, %{assigns | switch_loading: true}}

    def handle_event("plan_changed", %{value: plan}, assigns) do
      options = [
        %{label: "Team", value: "team"},
        %{label: "Free", value: "free"},
        %{label: "Pro", value: "pro", disabled: true}
      ]

      {:noreply, %{assigns | plan: plan, plan_options: options}}
    end
  end

  defmodule FormApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 180)

           root(FormView,
             notifications: false,
             switch_loading: false,
             plan: "free",
             plan_options: [
               %{label: "Free", value: "free"},
               %{label: "Pro", value: "pro", disabled: true},
               %{label: "Team", value: "team"}
             ]
           )
         end
       ]}
    end
  end

  test "switches and radio groups remain controlled through native interaction" do
    title = "GPUI Form Controls E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: FormApp, args: %{title: title})
    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 30, 26)

    Desktop.eventually(fn ->
      assert %{notifications: true} = assigns(runtime)
    end)

    Desktop.key!(window_id, "space")

    Desktop.eventually(fn ->
      assert %{notifications: false} = assigns(runtime)
    end)

    %{windows: [window]} = GPUI.Runtime.snapshot(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: window.id,
      event: "load_switch"
    })

    Desktop.eventually(fn -> assert %{switch_loading: true} = assigns(runtime) end)
    Desktop.await_frame!(runtime, 1, window_id)
    Desktop.refute_update!(runtime, fn -> Desktop.key!(window_id, "space") end)
    assert %{notifications: false} = assigns(runtime)

    Desktop.refute_update!(runtime, fn -> Desktop.click!(window_id, 100, 60) end)
    assert %{plan: "free"} = assigns(runtime)

    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "Right")

    Desktop.eventually(fn ->
      assert %{plan: "team"} = assigns(runtime)
      assert [%{value: "team"} | _options] = assigns(runtime).plan_options
    end)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
