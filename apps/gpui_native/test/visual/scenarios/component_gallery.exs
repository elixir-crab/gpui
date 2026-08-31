GPUITest.Examples.load!(:component_gallery)

defmodule GPUITest.Visual.ComponentGallery.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :component_gallery

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.ComponentGallery.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{story: "welcome"}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "GPUI Component Gallery"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "welcome"},
      %{name: "button", actions: [click("story-button")]},
      %{name: "progress", actions: [click("story-progress")]},
      %{name: "input", actions: [click("story-input")]},
      %{name: "select", actions: [click("story-select")]},
      %{name: "checkbox", actions: [click("story-checkbox")]},
      %{name: "switch", actions: [click("story-switch")]},
      %{name: "radio", actions: [click("story-radio")]},
      %{name: "slider", actions: [click("story-slider")]},
      %{name: "popover", actions: [click("story-popover"), click("story:popover:open")]},
      %{name: "tooltip", actions: [click("story-tooltip")]},
      %{name: "dialog", actions: [click("story-dialog"), click("story:dialog:open")]},
      %{name: "menu", actions: [click("story-menu"), click("story:menu:open")]},
      %{name: "tabs", actions: [click("story-tabs")]},
      %{name: "accordion", actions: [click("story-accordion")]},
      %{name: "virtual-list", actions: [click("story-virtual_list")]},
      %{name: "data-table", actions: [click("story-data_table")]},
      %{name: "tree", actions: [click("story-tree")]},
      %{name: "code-viewer", actions: [click("story-code_viewer")]}
    ]
  end

  defp click(event), do: {:dispatch, %{type: :click, window_id: 1, event: event}}
end
