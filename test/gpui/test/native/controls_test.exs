defmodule GPUI.Test.Native.ControlsTest do
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
          disabled={assigns.switch_disabled}
          loading={assigns.switch_loading}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="plan"
          label="Plan"
          value={assigns.plan}
          options={assigns.plan_options}
          orientation="horizontal"
          phx-change="plan_changed"
        />
      </div>
      """
    end
  end

  defp render_form(ui, opts \\ []) do
    defaults = [
      notifications: false,
      switch_disabled: false,
      switch_loading: false,
      plan: "free",
      plan_options: [
        %{label: "Free", value: "free"},
        %{label: "Pro", value: "pro", disabled: true},
        %{label: "Team", value: "team"}
      ]
    ]

    render(ui, FormView, Keyword.merge(defaults, opts))
  end

  test "switch supports pointer and keyboard activation with controlled rerenders", %{ui: ui} do
    render_form(ui)

    assert %{width: width, height: height} = bounds(ui, "notifications")
    assert width > 0
    assert height > 0

    click(ui, "notifications")

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "notifications_changed", value: true}}}

    render_form(ui, notifications: true)
    focus(ui, "notifications")
    press(ui, :space)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "notifications_changed", value: false}}}

    render_form(ui)
    focus(ui, "notifications")
    press(ui, :enter)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "notifications_changed", value: true}}}
  end

  test "disabled and loading switches block pointer and keyboard activation", %{ui: ui} do
    for unavailable <- [:switch_disabled, :switch_loading] do
      render_form(ui, [{unavailable, true}])
      focus(ui, "notifications")
      press(ui, :space)
      click(ui, "notifications")
      refute_receive {:gpui, ^ui, {:event, %{event: "notifications_changed"}}}
    end
  end

  test "radio keyboard navigation wraps and skips disabled options", %{ui: ui} do
    render_form(ui)
    focus(ui, "plan")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "plan_changed", value: "team"}}}

    render_form(ui, plan: "team")
    focus(ui, "plan")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "plan_changed", value: "free"}}}

    render_form(ui, plan: "free")
    focus(ui, "plan")
    press(ui, :arrow_left)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "plan_changed", value: "team"}}}
  end

  test "radio navigation follows controlled option order after rerender", %{ui: ui} do
    render_form(ui,
      plan: "team",
      plan_options: [
        %{label: "Team", value: "team"},
        %{label: "Free", value: "free"},
        %{label: "Pro", value: "pro", disabled: true}
      ]
    )

    focus(ui, "plan")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "plan_changed", value: "free"}}}

    resize(ui, {420, 220})
    settle(ui)
    assert %{width: width} = bounds(ui, "plan")
    assert width > 0
  end
end
