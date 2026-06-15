defmodule Mix.Tasks.Gpui.Host.Build do
  @moduledoc "Builds the Rust GPUI host executable."

  use Mix.Task

  @shortdoc "Builds native/gpui_host"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [real_gpui: :boolean])
    manifest = Path.expand("../../../native/gpui_host/Cargo.toml", __DIR__)
    cargo_args = ["build", "--release", "--manifest-path", manifest] ++ feature_args(opts)

    {output, status} =
      System.cmd("cargo", cargo_args,
        stderr_to_stdout: true,
        env: cargo_env()
      )

    Mix.shell().info(output)

    if status != 0 do
      Mix.raise("cargo build failed with status #{status}")
    end
  end

  defp feature_args(opts) do
    if Keyword.get(opts, :real_gpui, false), do: ["--features", "real-gpui"], else: []
  end

  defp cargo_env do
    path = System.get_env("PATH", "")
    cargo_bin = Path.expand("~/.cargo/bin")
    [{"PATH", cargo_bin <> ":" <> path}]
  end
end
