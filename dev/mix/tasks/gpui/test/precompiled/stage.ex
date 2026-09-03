defmodule Mix.Tasks.Gpui.Test.Precompiled.Stage do
  @moduledoc "Stages one workflow artifact in RustlerPrecompiled's local cache."

  use Mix.Task

  @shortdoc "Stages an untagged archive for no-Cargo validation"
  @switches [archive: :string, host: :string]

  @impl Mix.Task
  def run(args) do
    {options, []} = OptionParser.parse!(args, strict: @switches)
    archive = Keyword.fetch!(options, :archive)
    host = Keyword.fetch!(options, :host)
    root = File.cwd!()
    checksum = Path.join(root, "apps/gpui_native/checksum-Elixir.GPUI.Native.NIF.exs")
    cache = Path.join(root, ".precompiled-cache")

    unless host in ["vanilla", "gpui_component"], do: Mix.raise("unsupported host: #{host}")
    unless File.regular?(archive), do: Mix.raise("archive does not exist: #{archive}")

    digest =
      "sha256:" <> (:crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower))

    File.write!(checksum, inspect(%{Path.basename(archive) => digest}, pretty: true) <> "\n")
    File.mkdir_p!(cache)
    File.cp!(archive, Path.join(cache, Path.basename(archive)))
    Mix.shell().info("RUSTLER_PRECOMPILED_GLOBAL_CACHE_PATH=#{cache}")
  end
end
