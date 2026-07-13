defmodule GPUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :gpui,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: "https://github.com/dannote/gpui",
      homepage_url: "https://github.com/dannote/gpui",
      docs: docs(),
      dialyzer: [plt_add_apps: [:ex_unit]],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test, test_unit: :test, test_integration: :test, test_all: :test]
    ]
  end

  defp description do
    "Elixir/OTP bindings and HEEx-style UI DSL for Rust GPUI."
  end

  defp package do
    [
      name: "gpui",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/dannote/gpui"},
      files:
        ~w(lib codegen config/config.exs native/gpui/Cargo.toml native/gpui/src mix.exs rustq.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Core: [GPUI, GPUI.Application, GPUI.Session, GPUI.Snapshot, GPUI.Runtime, GPUI.View],
        Displays: [GPUI.Display, GPUI.Display.Native],
        Elements: [GPUI.Element, GPUI.Event, GPUI.Raster, GPUI.ResourceRef, GPUI.WindowSpec],
        Remote: [GPUI.Remote.Server, GPUI.Remote.Client, GPUI.Remote.Protocol]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_view, "~> 1.2"},
      {:rustler, "~> 0.38.0", runtime: false},
      {:rustq, "~> 0.9.6", only: [:dev, :test], runtime: false},
      {:vibe_kit, "== 0.1.5"},
      {:safe_rpc, "~> 0.1.3"},
      {:igniter, "~> 0.6", only: [:dev, :test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases() do
    [
      test_unit: ["test test/gpui test/gpui_test.exs"],
      test_integration: ["test test/integration"],
      test_all: ["test"],
      ci: [
        "compile --warnings-as-errors",
        "format",
        "rustq.check",
        "format --check-formatted",
        "rust.fmt --check",
        "rust.check",
        "rust.clippy",
        "rust.headless.clippy",
        "rust.core.clippy",
        "test_all",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ],
      "rustq.check": &rustq_check/1,
      "rust.fmt": &rust_fmt/1,
      "rust.check": &rust_check/1,
      "rust.clippy": &rust_clippy/1,
      "rust.headless.clippy": &rust_headless_clippy/1,
      "rust.core.clippy": &rust_core_clippy/1
    ]
  end

  defp rustq_check(_args) do
    {_, status} =
      System.cmd("mix", ["rustq.gen", "--check"],
        into: IO.stream(),
        stderr_to_stdout: true,
        env: [{"MIX_ENV", to_string(Mix.env())}]
      )

    if status != 0, do: Mix.raise("RustQ generated files are stale")
  end

  defp rust_fmt(args), do: rust_cmd(["fmt", "--manifest-path", "native/gpui/Cargo.toml"] ++ args)

  defp rust_check(_args), do: rust_cmd(["check", "--manifest-path", "native/gpui/Cargo.toml"])

  defp rust_clippy(_args), do: run_rust_clippy([])

  defp rust_headless_clippy(_args),
    do: run_rust_clippy(["--no-default-features", "--features", "real-gpui"])

  defp rust_core_clippy(_args), do: run_rust_clippy(["--no-default-features"])

  defp run_rust_clippy(feature_args) do
    rust_cmd(
      ["clippy", "--manifest-path", "native/gpui/Cargo.toml"] ++
        feature_args ++ ["--", "-D", "warnings"]
    )
  end

  defp rust_cmd(args) do
    env = [{"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")}]
    {_, status} = System.cmd("cargo", args, into: IO.stream(), stderr_to_stdout: true, env: env)

    if status != 0, do: Mix.raise("cargo #{Enum.join(args, " ")} failed")
  end
end
