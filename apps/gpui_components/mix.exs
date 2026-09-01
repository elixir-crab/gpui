defmodule GPUI.Components.MixProject do
  use Mix.Project

  @version "0.2.0-rc.1"
  @source_url "https://github.com/dannote/gpui"
  @umbrella_root __DIR__ |> Path.dirname() |> Path.dirname()

  def project do
    [
      app: :gpui_components,
      version: @version,
      build_path: Path.join(@umbrella_root, "_build"),
      config_path: Path.join(@umbrella_root, "config/config.exs"),
      deps_path: Path.join(@umbrella_root, "deps"),
      lockfile: Path.join(@umbrella_root, "mix.lock"),
      elixir: "~> 1.20",
      elixirc_options: [check_cwd: false],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Declarative conventional controls backed by gpui-component for GPUI.",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application, do: []

  defp package do
    [
      name: "gpui_components",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib native mix.exs README.md CHANGELOG.md LICENSE),
      exclude_patterns: [~r{^native/target(?:/|$)}]
    ]
  end

  defp deps do
    [
      {:gpui, "== #{@version}", in_umbrella: true, hex: :gpui}
    ]
  end
end
