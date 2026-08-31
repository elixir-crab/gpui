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
      %{name: "radio", actions: [click("story-radio")]},
      %{name: "dialog", actions: [click("story-dialog"), click("show-dialog")]},
      %{name: "data-table", actions: [click("story-data_table")]},
      %{name: "code-viewer", actions: [click("story-code_viewer")]}
    ]
  end

  defp click(event), do: {:dispatch, %{type: :click, window_id: 1, event: event}}
end
