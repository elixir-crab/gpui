defmodule GPUI.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :gpui,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: description(),
      source_url: "https://github.com/dannote/gpui",
      homepage_url: "https://github.com/dannote/gpui",
      docs: docs(),
      test_load_filters: [&load_test_file?/1],
      test_ignore_filters: [&ignore_test_file?/1],
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
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
        "ci.checks": :test,
        "ci.native": :test,
        "gpui.release.check": :release,
        "gpui.visual.capture": :e2e
      ]
    ]
  end

  defp load_test_file?(path) do
    String.ends_with?(path, "_test.exs") and
      (Mix.env() == :e2e or not String.contains?(path, "e2e/"))
  end

  defp ignore_test_file?(path) do
    String.contains?(path, "support/") or
      String.contains?(path, "test/visual/scenarios/") or
      (Mix.env() != :e2e and String.contains?(path, "e2e/"))
  end

  defp elixirc_paths(env) when env in [:dev, :test, :e2e, :release],
    do: ["lib", "dev"]

  defp elixirc_paths(_env), do: ["lib"]

  defp description do
    "Elixir/OTP bindings and HEEx-style UI DSL for Rust GPUI."
  end

  defp package do
    [
      name: "gpui",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/dannote/gpui"},
      files: package_files()
    ]
  end

  defp package_files do
    files =
      ~w(lib codegen examples guides config/config.exs native/gpui/Cargo.toml native/gpui/Cargo.lock native/gpui/compat native/gpui/src mix.exs rustq.exs rust-toolchain.toml README.md CHANGELOG.md LICENSE)

    if File.exists?("checksum-Elixir.GPUI.Native.exs") do
      ["checksum-Elixir.GPUI.Native.exs" | files]
    else
      files
    end
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      filter_modules: &documented_module?/2,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/introduction/getting-started.md",
        "guides/architecture/sessions-and-displays.md",
        "guides/architecture/compatibility-and-stability.md",
        "guides/architecture/editable-text-primitives.md",
        "guides/architecture/native-accessibility-boundaries.md",
        "guides/architecture/native-text-projection-boundaries.md",
        "guides/ui/components-and-styling.md",
        "guides/ui/commands-and-shortcuts.md",
        "guides/ui/overlays-and-menus.md",
        "guides/remote/remote-displays.md",
        "guides/testing/testing.md",
        "guides/deployment/native-builds.md"
      ],
      groups_for_extras: [
        Introduction: ~r/guides\/introduction\//,
        Architecture: ~r/guides\/architecture\//,
        UI: ~r/guides\/ui\//,
        Remote: ~r/guides\/remote\//,
        Testing: ~r/guides\/testing\//,
        Deployment: ~r/guides\/deployment\//
      ],
      groups_for_modules: [
        Core: [
          GPUI,
          GPUI.Application,
          GPUI.Command,
          GPUI.Session,
          GPUI.Snapshot,
          GPUI.Runtime,
          GPUI.Runtime.Update,
          GPUI.View
        ],
        Text: [
          GPUI.Text.Buffer,
          GPUI.Text.Position,
          GPUI.Text.Range,
          GPUI.Text.Edit,
          GPUI.Text.Selection,
          GPUI.Text.Transaction,
          GPUI.Text.Snapshot,
          GPUI.Text.Viewport,
          GPUI.Text.CaretGeometry,
          GPUI.Text.RangeGeometry,
          GPUI.Text.Rectangle,
          GPUI.Text.Decoration,
          GPUI.Text.InlineProjection,
          GPUI.Text.BlockProjection
        ],
        Displays: [GPUI.Display, GPUI.Display.Native],
        Elements: [
          GPUI.UI,
          GPUI.UI.Overlay,
          GPUI.Element,
          GPUI.Event,
          GPUI.Image,
          GPUI.Raster,
          GPUI.ResourceRef,
          GPUI.Tailwind,
          GPUI.Template,
          GPUI.WindowSpec
        ],
        Remote: [
          GPUI.Remote.Server,
          GPUI.Remote.Client,
          GPUI.Remote.Protocol,
          GPUI.Remote.Transport.TCP
        ],
        Testing: [GPUI.Test, GPUI.Test.Display]
      ]
    ]
  end

  defp documented_module?(module, _metadata) do
    module in documented_modules()
  end

  defp documented_modules do
    [
      GPUI,
      GPUI.Accessibility,
      GPUI.Application,
      GPUI.Schema.Component,
      GPUI.Command,
      GPUI.Session,
      GPUI.Snapshot,
      GPUI.Runtime,
      GPUI.Runtime.Update,
      GPUI.View,
      GPUI.Text.Buffer,
      GPUI.Text.Position,
      GPUI.Text.Range,
      GPUI.Text.Edit,
      GPUI.Text.Selection,
      GPUI.Text.Transaction,
      GPUI.Text.Snapshot,
      GPUI.Text.Viewport,
      GPUI.Text.CaretGeometry,
      GPUI.Text.RangeGeometry,
      GPUI.Text.Rectangle,
      GPUI.Text.Decoration,
      GPUI.Text.InlineProjection,
      GPUI.Text.BlockProjection,
      GPUI.Text.StyleRun,
      GPUI.Text.RichRun,
      GPUI.Transfer.Payload,
      GPUI.Transfer.Event,
      GPUI.Display,
      GPUI.Display.Native,
      GPUI.UI,
      GPUI.UI.Overlay,
      GPUI.Element,
      GPUI.Event,
      GPUI.Image,
      GPUI.Raster,
      GPUI.ResourceRef,
      GPUI.Tailwind,
      GPUI.Template,
      GPUI.WindowSpec,
      GPUI.Remote.Server,
      GPUI.Remote.Client,
      GPUI.Remote.Protocol,
      GPUI.Remote.Transport.TCP,
      GPUI.Test,
      GPUI.Test.Display,
      Mix.Tasks.Gpui.Release.Check
    ]
  end

  defp deps do
    [
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.3", only: [:dev, :release], runtime: false},
      {:file_system, "~> 1.0"},
      {:phoenix_live_view, "~> 1.2.6"},
      {:rustler, "~> 0.38.0", runtime: false},
      {:rustler_precompiled, "~> 0.9"},
      {:rustq, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:safe_rpc, "~> 0.1.14"},
      {:igniter, "~> 0.8.2", only: [:dev, :test]}
    ]
  end

  defp aliases() do
    [
      "ci.checks": [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test --exclude native",
        "credo --strict",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ],
      "ci.native": [
        "compile --warnings-as-errors",
        "rustq.check",
        "rust.fmt --check",
        "rust.check",
        "rust.clippy",
        "rust.headless.clippy",
        "rust.core.clippy",
        "rust.e2e.fmt --check",
        "rust.e2e.clippy",
        "rust.test",
        "test --only native",
        "dialyzer"
      ],
      ci: [
        "compile --warnings-as-errors",
        "rustq.check",
        "format --check-formatted",
        "rust.fmt --check",
        "rust.check",
        "rust.clippy",
        "rust.headless.clippy",
        "rust.core.clippy",
        "rust.e2e.fmt --check",
        "rust.e2e.clippy",
        "rust.test",
        "test",
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
      "rust.e2e.fmt": &rust_e2e_fmt/1,
      "rust.e2e.clippy": &rust_e2e_clippy/1,
      "rust.test": &rust_test/1
    ]
  end

  defp rustq_check(_args) do
    {_, status} =
      System.cmd("mix", ["rustq.gen", "--check"],
        into: IO.stream(),
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "dev"}]
      )

    if status != 0, do: Mix.raise("RustQ generated files are stale")
  end

  defp rust_fmt(args), do: rust_cmd(["fmt", "--manifest-path", "native/gpui/Cargo.toml"] ++ args)

  defp rust_check(_args), do: rust_cmd(["check", "--manifest-path", "native/gpui/Cargo.toml"])

  defp rust_clippy(_args), do: run_rust_clippy([])

  defp rust_headless_clippy(_args),
    do: run_rust_clippy(["--no-default-features", "--features", "real-gpui"])

  defp rust_core_clippy(_args), do: run_rust_clippy(["--no-default-features"])

  defp rust_e2e_fmt(args),
    do: rust_cmd(["fmt", "--manifest-path", "test/support/e2e_driver/Cargo.toml"] ++ args)

  defp rust_e2e_clippy(_args) do
    rust_cmd([
      "clippy",
      "--manifest-path",
      "test/support/e2e_driver/Cargo.toml",
      "--",
      "-D",
      "warnings"
    ])
  end

  defp rust_test(_args) do
    rust_cmd([
      "test",
      "--manifest-path",
      "native/gpui/Cargo.toml",
      "--all-features",
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
