defmodule Mix.Tasks.Gpui.Test.Precompiled.Stage do
  @moduledoc "Stages one workflow artifact in RustlerPrecompiled's local cache."

  use Mix.Task

  @shortdoc "Stages an untagged archive for no-Cargo validation"
  @switches [archive_root: :string, target: :string, host: :string]

  @impl Mix.Task
  def run(args) do
    {options, []} = OptionParser.parse!(args, strict: @switches)
    archive_root = Keyword.get(options, :archive_root) || System.fetch_env!("ARCHIVE_ROOT")
    target = Keyword.get(options, :target) || System.fetch_env!("TARGET")
    host = Keyword.get(options, :host) || System.fetch_env!("HOST")
    host_atom = parse_host!(host)
    version = Mix.Project.config() |> Keyword.fetch!(:version)
    archive_name = GPUI.Dev.Release.Archive.archive_name(version, target, host_atom)
    archive = find_archive!(archive_root, archive_name)
    root = File.cwd!()
    checksum = Path.join(root, "apps/gpui_native/checksum-Elixir.GPUI.Native.NIF.exs")
    cache = Path.join(root, ".precompiled-cache")

    digest =
      "sha256:" <> (:crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower))

    File.write!(checksum, inspect(%{archive_name => digest}, pretty: true) <> "\n")
    File.mkdir_p!(cache)
    File.cp!(archive, Path.join(cache, archive_name))
  end

  defp find_archive!(root, archive_name) do
    root
    |> Path.expand()
    |> Path.join("**/#{archive_name}")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> case do
      [path] -> path
      [] -> Mix.raise("artifact archive not found: #{archive_name}")
      _many -> Mix.raise("artifact archive is ambiguous: #{archive_name}")
    end
  end

  defp parse_host!("vanilla"), do: :vanilla
  defp parse_host!("gpui_component"), do: :gpui_component
  defp parse_host!(host), do: Mix.raise("unsupported host: #{host}")
end
