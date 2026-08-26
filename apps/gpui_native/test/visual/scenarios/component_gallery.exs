GPUITest.Examples.load!(:component_gallery)

defmodule GPUITest.Visual.ComponentGallery.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :component_gallery

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.ComponentGallery.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{story: "actions"}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "GPUI Component Gallery"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "actions"},
      %{name: "forms", actions: [click("story-forms")]},
      %{name: "overlays", actions: [click("story-overlays"), click("show-dialog")]},
      %{name: "collections", actions: [click("story-collections")]},
      %{name: "code", actions: [click("story-code")]}
    ]
  end

  defp click(event), do: {:dispatch, %{type: :click, window_id: 1, event: event}}
end
