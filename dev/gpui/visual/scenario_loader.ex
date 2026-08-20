defmodule GPUI.Dev.Visual.ScenarioLoader do
  @moduledoc "Development loader for isolated visual regression scenarios."

  @scenario_dir Path.expand("../../../test/visual/scenarios", __DIR__)

  @spec load!(String.t() | atom()) :: [{module(), binary()}] | nil
  def load!(scenario) do
    scenario
    |> to_string()
    |> then(&Path.join(@scenario_dir, &1 <> ".exs"))
    |> Code.require_file()
  end
end
