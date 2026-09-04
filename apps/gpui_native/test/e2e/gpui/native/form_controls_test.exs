defmodule GPUI.Native.FormControlsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule FormView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[240px] p-4 gap-4 bg-slate-900 text-white">
        <GPUI.UI.input
          id="form-name"
          label="Name"
          value={assigns.name}
          focus_request={assigns.name_focus_request}
          phx-change="name_changed"
          phx-submit="name_submitted"
        />
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
    def handle_event("name_changed", %{value: name}, assigns),
      do: {:noreply, %{assigns | name: name}}

    def handle_event("name_submitted", %{value: name}, assigns),
      do: {:noreply, %{assigns | name: name, submitted_name: name}}

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
           size(360, 240)

           root(FormView,
             name: "Ada",
             name_focus_request: 1,
             submitted_name: nil,
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

    runtime =
      start_runtime!(desktop,
        app: FormApp,
        args: %{title: title},
        display_opts: [theme: :dark]
      )

    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    Desktop.capture_fixture!(desktop, window, "form-controls")

    assert %{notifications: false, plan: "free"} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  test "desktop single-line input submits once without inserting a newline", %{
    desktop: desktop
  } do
    title = "GPUI Input Submit E2E #{System.unique_integer([:positive])}"

    runtime =
      start_runtime!(desktop,
        app: FormApp,
        args: %{title: title},
        display_opts: [theme: :dark]
      )

    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    Desktop.type!(desktop, window, "X")
    Desktop.press!(desktop, window, "Return")
    Process.sleep(100)

    assert %{name: name, submitted_name: submitted_name} = assigns(runtime)
    assert submitted_name == name
    assert name != ""
    refute String.contains?(name, "\n")
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
