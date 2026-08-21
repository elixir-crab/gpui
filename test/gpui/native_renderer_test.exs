defmodule GPUI.Test.NativeTest do
  use GPUI.Test, native: [size: {320, 160}]

  defmodule FormView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[320px] h-[160px] gap-4">
        <GPUI.UI.switch
          id="notifications"
          label="Notifications"
          checked={assigns.notifications}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="plan"
          label="Plan"
          value={assigns.plan}
          options={[
            %{label: "Free", value: "free"},
            %{label: "Pro", value: "pro", disabled: true},
            %{label: "Team", value: "team"}
          ]}
          orientation="horizontal"
          phx-change="plan_changed"
        />
      </div>
      """
    end
  end

  test "drives native controls through an ExUnit-owned UI", %{ui: ui} do
    render(ui, FormView, notifications: false, plan: "free")

    assert %{width: width, height: height} = bounds(ui, "notifications")
    assert width > 0
    assert height > 0

    click(ui, "notifications")

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "notifications_changed", value: true}}}

    render(ui, FormView, notifications: true, plan: "free")
    focus(ui, "plan")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "plan_changed", value: "team"}}}
  end
end
