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

  defmodule DialogView do
    use GPUI.View

    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <Overlay.dialog
        id="settings-dialog"
        open={assigns.open}
        title="Settings"
        width={280}
        phx-change="dialog_changed"
      >
        <:trigger>
          <button id="dialog-trigger"><text>Open settings</text></button>
        </:trigger>
        <:content>
          <button id="dialog-action" phx-click="dialog_action"><text>Apply</text></button>
        </:content>
      </Overlay.dialog>
      """
    end
  end

  defmodule AccordionView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <GPUI.UI.accordion
        id="settings-sections"
        expanded={assigns.expanded}
        multiple={true}
        disabled={assigns.disabled}
        phx-change="sections_changed"
      >
        <GPUI.UI.accordion_item id="account" title="Account">
          <text>Account settings</text>
        </GPUI.UI.accordion_item>
        <GPUI.UI.accordion_item id="security" title="Security">
          <text>Security settings</text>
        </GPUI.UI.accordion_item>
      </GPUI.UI.accordion>
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

  defp render_accordion(ui, opts \\ []) do
    defaults = [expanded: [], disabled: false]
    render(ui, AccordionView, Keyword.merge(defaults, opts))
    settle(ui)
  end

  test "dialog trigger has stable bounds and requests a controlled open state", %{ui: ui} do
    render(ui, DialogView, open: false)
    settle(ui)

    assert %{width: width, height: height} = bounds(ui, "settings-dialog")
    assert width > 0
    assert height > 0

    focus(ui, "settings-dialog")
    press(ui, :enter)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "dialog_changed", value: true}}}
  end

  test "dialog opens in the native top layer and routes Escape closure", %{ui: ui} do
    render(ui, DialogView, open: true)
    settle(ui)
    press(ui, :escape)

    assert_receive {:gpui, ^ui, {:event, %{type: :change, event: "dialog_changed", value: false}}}
  end

  test "accordion items expose stable targets and controlled pointer changes", %{ui: ui} do
    render_accordion(ui)

    assert %{width: width, height: height} = bounds(ui, "settings-sections")
    assert width > 0
    assert height > 0
    assert %{height: item_height} = bounds(ui, "account")
    assert item_height > 0

    click(ui, "account")

    assert_receive {:gpui, ^ui,
                    {:event, %{type: :change, event: "sections_changed", value: ["account"]}}}

    render_accordion(ui, expanded: ["account"])
    click(ui, "security")

    assert_receive {:gpui, ^ui,
                    {:event,
                     %{
                       type: :change,
                       event: "sections_changed",
                       value: ["account", "security"]
                     }}}
  end

  test "disabled accordion groups suppress pointer changes", %{ui: ui} do
    render_accordion(ui, disabled: true)
    click(ui, "account")
    refute_receive {:gpui, ^ui, {:event, _event}}
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
