defmodule GPUI.Dev.NativeWorkspace do
  @moduledoc """
  Executes commands against the repository-owned native Cargo workspace.

  Main-workspace commands consistently use the repository manifest and lockfile.
  Standalone tooling crates, such as the Linux desktop driver, remain outside
  this service.
  """

  @manifest "Cargo.toml"

  @type option ::
          {:package, String.t()}
          | {:features, String.t() | [String.t()]}
          | {:all_features, boolean()}
          | {:no_default_features, boolean()}

  @selection_switches [
    package: :string,
    features: :string,
    all_features: :boolean,
    no_default_features: :boolean
  ]

  @doc "Returns decoded Cargo metadata for the requested feature graph."
  @spec metadata!([String.t()]) :: map()
  def metadata!(feature_args \\ []) do
    ["metadata", "--format-version", "1" | feature_args]
    |> output!()
    |> JSON.decode!()
  end

  @doc "Checks the complete native workspace."
  @spec check_workspace!() :: :ok
  def check_workspace!, do: stream!(["check", "--workspace"])

  @doc "Checks a package with an exact feature selection."
  @spec check!([option()]) :: :ok
  def check!(options \\ []), do: stream!(["check" | selection_args(options)])

  @doc "Runs library tests for a package or the workspace."
  @spec test!([option()]) :: :ok
  def test!(options \\ []), do: stream!(["test" | selection_args(options)] ++ ["--lib"])

  @doc "Runs Clippy with warnings denied."
  @spec clippy!([option()]) :: :ok
  def clippy!(options \\ []) do
    stream!(["clippy" | selection_args(options)] ++ ["--", "-D", "warnings"])
  end

  @doc "Formats all workspace crates."
  @spec fmt!([String.t()]) :: :ok
  def fmt!(args \\ []), do: stream!(["fmt", "--all" | args], locked: false)

  @doc "Audits the workspace lockfile and denies the selected advisory class."
  @spec audit!([String.t()]) :: :ok
  def audit!(args \\ []),
    do: stream!(["audit", "--deny", "unsound" | args], manifest: false, locked: false)

  @doc false
  @spec output!([String.t()]) :: String.t()
  def output!(args) do
    command_args = workspace_args(args)

    case System.cmd("cargo", command_args, stderr_to_stdout: true, env: cargo_env()) do
      {output, 0} -> output
      {output, _status} -> raise "cargo #{Enum.join(command_args, " ")} failed:\n#{output}"
    end
  end

  defp stream!(args, options \\ []) do
    command_args = workspace_args(args, options)

    {_, status} =
      System.cmd("cargo", command_args,
        env: cargo_env(),
        into: IO.stream(),
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("cargo #{Enum.join(command_args, " ")} failed")
    :ok
  end

  defp workspace_args(args, options \\ []) do
    locked = Keyword.get(options, :locked, true)
    manifest = Keyword.get(options, :manifest, true)
    lock_args = if locked, do: ["--locked"], else: []

    manifest_args =
      if manifest, do: ["--manifest-path", @manifest], else: ["--file", "Cargo.lock"]

    insert_global_args(args, lock_args ++ manifest_args)
  end

  defp insert_global_args(args, global_args) do
    case Enum.split_while(args, &(&1 != "--")) do
      {cargo_args, []} -> cargo_args ++ global_args
      {cargo_args, rustc_args} -> cargo_args ++ global_args ++ rustc_args
    end
  end

  defp selection_args(options) do
    options
    |> Keyword.update(:features, nil, fn
      features when is_list(features) -> Enum.join(features, ",")
      features -> features
    end)
    |> OptionParser.to_argv(switches: @selection_switches)
  end

  defp cargo_env,
    do: [{"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")}]
end
