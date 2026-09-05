defmodule Mix.Tasks.Gpui.Release.Glibc.Check do
  @moduledoc "Checks a RustlerPrecompiled archive against a maximum GLIBC version."

  use Mix.Task

  @shortdoc "Checks an archive's required GLIBC symbol versions"
  @switches [archive: :string, max_version: :string]

  @impl Mix.Task
  def run(args) do
    {options, remaining} = OptionParser.parse!(args, strict: @switches)
    if remaining != [], do: Mix.raise("unexpected arguments: #{Enum.join(remaining, " ")}")

    archive = options |> Keyword.fetch!(:archive) |> Path.expand()
    maximum = Keyword.fetch!(options, :max_version)
    :ok = GPUI.Maintainer.Release.Glibc.check_archive!(archive, max: maximum)
    Mix.shell().info("#{Path.basename(archive)} requires no GLIBC newer than #{maximum}")
  end
end
