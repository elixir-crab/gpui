GPUITest.Examples.load!(:hello_window)

defmodule GPUITest.Visual.HelloWindow.Scenario do
  @behaviour GPUI.Maintainer.Visual.Scenario

  @impl GPUI.Maintainer.Visual.Scenario
  def id, do: :hello_window

  @impl GPUI.Maintainer.Visual.Scenario
  def app, do: GettingStarted.HelloWindow.App

  @impl GPUI.Maintainer.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Maintainer.Visual.Scenario
  def title, do: "Hello GPUI"

  @impl GPUI.Maintainer.Visual.Scenario
  def captures, do: [%{name: "hello-window"}]
end
