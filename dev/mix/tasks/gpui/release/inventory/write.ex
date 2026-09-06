defmodule Mix.Tasks.Gpui.Release.Inventory.Write do
  @moduledoc "Writes Cargo metadata and Mix dependency inventories."

  use Mix.Task

  @shortdoc "Writes release dependency inventories"
  @switches [output: :string]

  @impl Mix.Task
  def run(args) do
    {options, []} = OptionParser.parse!(args, strict: @switches)
    GPUI.Maintainer.Release.Inventory.write!(Keyword.get(options, :output, "release-inventory"))
  end
end
