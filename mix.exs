defmodule GPUI.MixProject do
  use Mix.Project

  def project do
    [
      app: :gpui,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:rustq, "~> 0.5", only: [:dev, :test], runtime: false},
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
        "format",
        "rustq.gen --check",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test_unit",
        "test_integration",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end
end
