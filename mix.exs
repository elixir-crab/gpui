defmodule GPUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :gpui,
      version: "0.1.0-rc",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: "https://github.com/dannote/gpui",
      homepage_url: "https://github.com/dannote/gpui",
      docs: docs(),
      test_load_filters: [&load_test_file?/1],
      test_ignore_filters: [&ignore_test_file?/1],
      dialyzer: [plt_add_apps: [:ex_unit]],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl]
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test,
        test_unit: :test,
        test_integration: :test,
        test_e2e: :test,
        test_all: :test
      ]
    ]
  end

  defp load_test_file?(path) do
    String.ends_with?(path, "_test.exs") and
      (System.get_env("GPUI_E2E") == "1" or not String.contains?(path, "e2e/"))
  end

  defp ignore_test_file?(path) do
    String.contains?(path, "support/") or
      (System.get_env("GPUI_E2E") != "1" and String.contains?(path, "e2e/"))
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
        ~w(lib codegen config/config.exs native/gpui/Cargo.toml native/gpui/Cargo.lock native/gpui/src mix.exs rustq.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [GPUI, GPUI.Application, GPUI.Session, GPUI.Snapshot, GPUI.Runtime, GPUI.View],
        Displays: [GPUI.Display, GPUI.Display.Native],
        Elements: [GPUI.Element, GPUI.Event, GPUI.Raster, GPUI.ResourceRef, GPUI.WindowSpec],
        Remote: [GPUI.Remote.Server, GPUI.Remote.Client, GPUI.Remote.Protocol]
      ]
    ]
  end

  defp deps do
    [
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false},
      {:phoenix_live_view, "~> 1.2.6"},
      {:rustler, "~> 0.38.0", runtime: false},
      {:rustq, "~> 0.9.8", only: [:dev, :test], runtime: false},
      {:safe_rpc, "~> 0.1.14"},
      {:igniter, "~> 0.8.2", only: [:dev, :test]}
    ]
  end

  defp aliases() do
    [
      test_unit: ["test test/gpui test/gpui_test.exs"],
      test_integration: ["test test/integration"],
      test_e2e: &test_e2e/1,
      test_all: ["test"],
      ci: [
        "compile --warnings-as-errors",
        "rustq.check",
        "format --check-formatted",
        "rust.fmt --check",
        "rust.check",
        "rust.clippy",
        "rust.headless.clippy",
        "rust.core.clippy",
        "rust.test",
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
      "rust.core.clippy": &rust_core_clippy/1,
      "rust.test": &rust_test/1
    ]
  end

  defp test_e2e(_args) do
    {_, status} =
      System.cmd(Path.expand("scripts/desktop-smoke", __DIR__), [],
        into: IO.stream(),
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("desktop E2E suite failed")
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

  defp rust_test(_args) do
    rust_cmd([
      "test",
      "--manifest-path",
      "native/gpui/Cargo.toml",
      "--no-default-features",
      "--features",
      "real-gpui",
      "--lib"
    ])
  end

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
