GPUITest.Examples.load!(:focus_timer)

defmodule GPUITest.Visual.FocusTimer.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :focus_timer

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GettingStarted.FocusTimer.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{seconds: 2}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Focus Timer"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "ready"},
      %{
        name: "running",
        actions: [
          {:dispatch, %{type: :click, window_id: 1, event: "start"}},
          {:send_view, 1, :tick}
        ]
      },
      %{
        name: "paused",
        actions: [{:dispatch, %{type: :click, window_id: 1, event: "pause"}}]
      },
      %{
        name: "complete",
        actions: [
          {:dispatch, %{type: :click, window_id: 1, event: "start"}},
          {:send_view, 1, :tick}
        ]
      }
    ]
  end
end
