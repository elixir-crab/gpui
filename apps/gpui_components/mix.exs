defmodule GPUI.Components.MixProject do
  use Mix.Project

  @version "0.2.0-dev"
  @source_url "https://github.com/dannote/gpui"

  def project do
    [
      app: :gpui_components,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
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
