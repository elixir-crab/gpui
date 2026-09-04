defmodule GPUI.Components.MixProject do
  use Mix.Project

  @version "0.2.0-rc.2"
  @source_url "https://github.com/elixir-crab/gpui"
  @umbrella_root __DIR__ |> Path.dirname() |> Path.dirname()
  @in_umbrella File.exists?(Path.join(@umbrella_root, "mix.exs"))

  def project do
    [
      app: :gpui_components,
      version: @version,
      build_path: project_path("_build", "_build"),
      config_path: project_path("config/config.exs", "config/config.exs"),
      deps_path: project_path("deps", "deps"),
      lockfile: project_path("mix.lock", "mix.lock"),
      elixir: "~> 1.20",
      elixirc_options: [check_cwd: false],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Declarative conventional controls backed by gpui-component for GPUI.",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  def application, do: []

  defp project_path(umbrella_path, package_path) do
    if @in_umbrella, do: Path.join(@umbrella_root, umbrella_path), else: package_path
  end

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
      gpui_dependency(),
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false}
    ]
  end

  defp gpui_dependency do
    case System.get_env("GPUI_PACKAGE_VALIDATION_ROOT") do
      nil ->
        if @in_umbrella,
          do: {:gpui, "== #{@version}", in_umbrella: true, hex: :gpui},
          else: {:gpui, "== #{@version}"}

      root ->
        {:gpui, path: Path.join(root, "gpui"), override: true}
    end
  end

  defp docs do
    [
      main: "GPUI.UI",
      source_ref: "v#{@version}",
      filter_modules: &documented_module?/2,
      groups_for_modules: [
        Components: [GPUI.UI, GPUI.UI.Overlay],
        Collections: [
          GPUI.UI.Collection,
          GPUI.UI.Collection.Source,
          GPUI.UI.Collection.Selection
        ],
        "Advanced schema": [GPUI.Components.Schema, GPUI.Components.NativeContract]
      ]
    ]
  end

  defp documented_module?(module, _metadata) do
    module in [
      GPUI.UI,
      GPUI.UI.Overlay,
      GPUI.UI.Collection,
      GPUI.UI.Collection.Source,
      GPUI.UI.Collection.Selection,
      GPUI.Components.Schema,
      GPUI.Components.NativeContract
    ]
  end
end
