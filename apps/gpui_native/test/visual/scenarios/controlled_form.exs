GPUITest.Examples.load!(:controlled_form)

defmodule GPUITest.Visual.ControlledForm.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :controlled_form

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GettingStarted.ControlledForm.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Controlled Form"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "saved"},
      %{
        name: "validation-error",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "name_changed", value: ""}},
          {:dispatch, %{type: :click, window_id: 1, event: "save"}}
        ]
      }
    ]
  end
end
