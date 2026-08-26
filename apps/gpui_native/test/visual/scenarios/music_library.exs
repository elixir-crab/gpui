GPUITest.Examples.load!(:music_library)

defmodule GPUITest.Visual.MusicLibrary.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :music_library

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.MusicLibrary.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Afterglow Music"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "library"},
      %{
        name: "search-results",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "search_changed", value: "northline"}}
        ]
      },
      %{
        name: "paused",
        actions: [
          {:dispatch, %{type: :click, window_id: 1, event: "toggle_play"}}
        ]
      }
    ]
  end
end
