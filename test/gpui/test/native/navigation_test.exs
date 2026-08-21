defmodule GPUI.Test.Native.NavigationTest do
  use GPUI.Test, native: [size: {360, 220}]

  defmodule TabsView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <GPUI.UI.tabs
        id="settings-tabs"
        value={assigns.section}
        options={assigns.options}
        disabled={assigns.disabled}
        variant="segmented"
        phx-change="section_changed"
      />
      """
    end
  end

  defp render_tabs(ui, opts \\ []) do
    defaults = [
      section: "general",
      disabled: false,
      options: [
        %{label: "General", value: "general"},
        %{label: "Advanced", value: "advanced"},
        %{label: "Audit", value: "audit"}
      ]
    ]

    render(ui, TabsView, Keyword.merge(defaults, opts))
  end

  test "tabs expose stable bounds and deterministic keyboard navigation", %{ui: ui} do
    render_tabs(ui)

    assert %{width: width, height: height} = bounds(ui, "settings-tabs")
    assert width > 0
    assert height > 0

    focus(ui, "settings-tabs")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "section_changed", value: "advanced"}}}

    render_tabs(ui, section: "advanced")
    focus(ui, "settings-tabs")
    press(ui, :arrow_left)

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "section_changed", value: "general"}}}
  end

  test "disabled tabs do not emit keyboard changes", %{ui: ui} do
    render_tabs(ui, disabled: true)
    focus(ui, "settings-tabs")
    press(ui, :arrow_right)
    refute_receive {:gpui, ^ui, {:event, _event}}
  end
end
