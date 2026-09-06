defmodule Mix.Tasks.Gpui.Release.Changelog.Extract do
  @moduledoc "Extracts one canonical release section into a notes file."

  use Mix.Task

  @shortdoc "Extracts canonical release notes"
  @switches [changelog: :string, version: :string, output: :string]

  @impl Mix.Task
  def run(args) do
    {options, []} = OptionParser.parse!(args, strict: @switches)
    changelog = Keyword.fetch!(options, :changelog)
    version = Keyword.fetch!(options, :version)
    output = Keyword.fetch!(options, :output)

    notes = GPUI.Maintainer.Release.Changelog.release_notes!(changelog, version)
    File.mkdir_p!(Path.dirname(output))
    File.write!(output, notes)
  end
end
