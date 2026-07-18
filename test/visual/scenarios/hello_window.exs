Code.require_file(
  "../../../examples/getting_started/support/hello_window.exs",
  __DIR__
)

defmodule GPUITest.Visual.HelloWindow.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :hello_window

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GettingStarted.HelloWindow.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Hello GPUI"

  @impl GPUI.Dev.Visual.Scenario
  def captures, do: [%{name: "hello-window"}]
end
