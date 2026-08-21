defmodule GPUI.Native.FormControlsE2ETest do
  use GPUI.Test, desktop: true

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule FormView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[180px] p-4 gap-4 bg-white text-slate-900">
        <GPUI.UI.switch
          id="form-notifications"
          label="Notifications"
          checked={assigns.notifications}
          loading={assigns.switch_loading}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="form-plan"
          label="Plan"
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

  test "desktop renders controlled form controls", %{desktop: desktop} do
    title = "GPUI Form Controls E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: FormApp, args: %{title: title})

    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)

    assert %{notifications: false, plan: "free"} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
