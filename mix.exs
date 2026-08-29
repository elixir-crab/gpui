defmodule GPUI.Umbrella.MixProject do
  use Mix.Project

  @version "0.2.0-dev"

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test,
        "ci.checks": :test,
        "ci.native": :test,
        "gpui.test.codegen": :test,
        "gpui.test.hosts": :test,
        "gpui.test.packages": :test,
        "gpui.release.check": :release,
        "gpui.test.e2e": :e2e,
        "gpui.test.mode_switch": :dev,
        "gpui.visual.capture": :e2e
      ]
    ]
  end

  defp deps do
    [
      {:ex_slop, "~> 0.4", runtime: false},
      {:quickbeam, "~> 0.11.0", runtime: false},
      {:reach, "~> 2.0", runtime: false},
      {:ex_dna, "~> 1.0", runtime: false},
      {:dialyxir, "~> 1.0", runtime: false},
      {:credo, "~> 1.0", runtime: false},
      {:ex_doc, "~> 0.40.3", runtime: false},
      {:rustq, "~> 1.0.0-rc.6", runtime: false},
      {:igniter, "~> 0.8.2"}
    ]
  end

  defp aliases do
    [
      "ci.checks": [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "gpui.tailwind.palette --check",
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
        "gpui.test.codegen",
        "gpui.test.native"
      ],
      ci: [
        "compile --warnings-as-errors",
        "rustq.check",
        "format --check-formatted",
        "gpui.tailwind.palette --check",
        "rust.fmt --check",
        "rust.check",
        "rust.clippy",
        "rust.headless.clippy",
        "rust.core.clippy",
        "rust.e2e.fmt --check",
        "rust.e2e.clippy",
        "rust.test",
        "gpui.test.codegen",
        "gpui.test.packages",
        "test",
        "credo --strict",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells",
        "gpui.test.native"
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
    Mix.Task.run("rustq.gen", ["--check"])
  end

  defp rust_fmt(args),
    do: rust_cmd(["fmt", "--manifest-path", native_manifest()] ++ args)

  defp rust_check(_args), do: rust_cmd(["check", "--manifest-path", native_manifest()])
  defp rust_clippy(_args), do: run_rust_clippy([])

  defp rust_headless_clippy(_args),
    do: run_rust_clippy(["--no-default-features", "--features", "real-gpui"])

  defp rust_core_clippy(_args),
    do: run_rust_clippy(["--no-default-features", "--features", "vanilla-host"])

  defp rust_e2e_fmt(args),
    do: rust_cmd(["fmt", "--manifest-path", e2e_manifest()] ++ args)

  defp rust_e2e_clippy(_args),
    do: rust_cmd(["clippy", "--manifest-path", e2e_manifest(), "--", "-D", "warnings"])

  defp rust_test(_args),
    do: rust_cmd(["test", "--manifest-path", native_manifest(), "--all-features", "--lib"])

  defp run_rust_clippy(feature_args),
    do:
      rust_cmd(
        ["clippy", "--manifest-path", native_manifest()] ++
          feature_args ++ ["--", "-D", "warnings"]
      )

  defp native_manifest, do: "apps/gpui_native/native/gpui/Cargo.toml"
  defp e2e_manifest, do: "apps/gpui_native/test/support/desktop/drivers/linux/Cargo.toml"

  defp rust_cmd(args) do
    env = [{"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")}]
    {_, status} = System.cmd("cargo", args, into: IO.stream(), stderr_to_stdout: true, env: env)

    if status != 0, do: Mix.raise("cargo #{Enum.join(args, " ")} failed")
  end
end
