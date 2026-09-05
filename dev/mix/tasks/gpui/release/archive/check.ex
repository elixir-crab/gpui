defmodule Mix.Tasks.Gpui.Release.Archive.Check do
  @moduledoc "Validates one RustlerPrecompiled archive for its target and host."

  use Mix.Task

  @shortdoc "Validates one native release archive"
  @switches [archive: :string, target: :string, host: :string, version: :string]

  @impl Mix.Task
  def run(args) do
    {options, []} = OptionParser.parse!(args, strict: @switches)

    archive = Keyword.get(options, :archive) || System.fetch_env!("ARCHIVE")

    GPUI.Maintainer.Release.Archive.check!(archive,
      target: Keyword.fetch!(options, :target),
      host: parse_host!(Keyword.fetch!(options, :host)),
      version: Keyword.fetch!(options, :version)
    )
  end

  defp parse_host!("vanilla"), do: :vanilla
  defp parse_host!("gpui-component"), do: :gpui_component
  defp parse_host!(host), do: Mix.raise("unsupported native host: #{host}")
end
