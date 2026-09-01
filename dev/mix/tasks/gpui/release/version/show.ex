defmodule Mix.Tasks.Gpui.Release.Version.Show do
  @moduledoc "Prints typed package version metadata for release workflows."

  use Mix.Task

  @shortdoc "Prints package release version metadata"
  @switches [package: :string, github_output: :boolean]

  @impl Mix.Task
  def run(args) do
    {options, positional} = OptionParser.parse!(args, strict: @switches)
    package = Keyword.get(options, :package) || List.first(positional) || "gpui_native"
    version = GPUI.Dev.Release.Version.fetch!(package)

    if options[:github_output] do
      output = System.fetch_env!("GITHUB_OUTPUT")

      File.write!(
        output,
        [
          "version=",
          to_string(version),
          "\nprerelease=",
          to_string(GPUI.Dev.Release.Version.prerelease?(version)),
          "\n"
        ],
        [:append]
      )
    else
      Mix.shell().info(to_string(version))
    end
  end
end
