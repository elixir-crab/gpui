Code.require_file(
  "../../../examples/getting_started/support/settings_form.exs",
  __DIR__
)

defmodule GPUITest.Visual.SettingsForm.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :settings_form

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GettingStarted.SettingsForm.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Workspace Settings"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "settings"},
      %{
        name: "unsaved-paper-theme",
        actions: [
          {:dispatch,
           %{type: :change, window_id: 1, event: "name_changed", value: "Grace Hopper"}},
          {:dispatch, %{type: :change, window_id: 1, event: "preview_changed", value: "paper"}},
          {:dispatch, %{type: :change, window_id: 1, event: "density_changed", value: "compact"}},
          {:dispatch,
           %{type: :change, window_id: 1, event: "notifications_changed", value: false}},
          {:dispatch, %{type: :change, window_id: 1, event: "volume_changed", value: 40.0}}
        ]
      },
      %{
        name: "review-dialog",
        actions: [{:dispatch, %{type: :click, window_id: 1, event: "review"}}]
      }
    ]
  end
end
