defmodule GPUI.Dev.Visual.ScenarioLoader do
  @moduledoc "Development loader for isolated visual regression scenarios."

  @project_root GPUI.Dev.Paths.app(:gpui_native)
  @scenario_dir Path.join(@project_root, "test/visual/scenarios")

  @spec load!(String.t() | atom()) :: [{module(), binary()}] | nil
  def load!(scenario) do
    scenario
    |> to_string()
    |> then(&Path.join(@scenario_dir, &1 <> ".exs"))
    |> Code.require_file()
  end
end
