defmodule GPUI.Native.MixProject do
  use Mix.Project

  @version "0.2.0-rc.2"
  @source_url "https://github.com/elixir-crab/gpui"
  @umbrella_root __DIR__ |> Path.dirname() |> Path.dirname()
  @in_umbrella File.exists?(Path.join(@umbrella_root, "mix.exs"))

  def project do
    [
      app: :gpui_native,
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
      description: "RustlerPrecompiled native GPUI hosts for GPUI.",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_load_filters: [&load_test_file?/1],
      test_ignore_filters: [&ignore_test_file?/1]
    ]
  end

  def application, do: []

  defp project_path(umbrella_path, package_path) do
    if @in_umbrella, do: Path.join(@umbrella_root, umbrella_path), else: package_path
  end

  defp elixirc_paths(env) do
    if @in_umbrella and env in [:dev, :test, :e2e, :release],
      do: ["lib", Path.join(@umbrella_root, "dev")],
      else: ["lib"]
  end

  defp load_test_file?(path) do
    String.ends_with?(path, "_test.exs") and
      (Mix.env() == :e2e or not String.contains?(path, "e2e/")) and
      (Mix.target() == :native_test or not String.contains?(path, "test/gpui/test/native/"))
  end

  defp ignore_test_file?(path) do
    String.contains?(path, "support/") or
      String.contains?(path, "test/visual/scenarios/") or
      (Mix.target() != :native_test and String.contains?(path, "test/gpui/test/native/")) or
      (Mix.env() != :e2e and String.contains?(path, "e2e/"))
  end

  defp package do
    files = ~w(lib native mix.exs README.md CHANGELOG.md LICENSE)

    files =
      if File.exists?("checksum-Elixir.GPUI.Native.NIF.exs"),
        do: ["checksum-Elixir.GPUI.Native.NIF.exs" | files],
        else: files

    [
      name: "gpui_native",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: files,
      exclude_patterns: [~r{^native/(?:target|gpui/target)(?:/|$)}]
    ]
  end

  defp deps do
    [
      public_dependency(:gpui),
      public_dependency(:gpui_components),
      {:json_codec, "~> 0.2.3", only: [:dev, :test, :release], runtime: false},
      {:rustler, "~> 0.38.0", runtime: false},
      {:rustler_precompiled, "~> 0.9"},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false}
    ]
  end

  defp public_dependency(app) do
    case System.get_env("GPUI_PACKAGE_VALIDATION_ROOT") do
      nil ->
        if @in_umbrella,
          do: {app, "== #{@version}", in_umbrella: true, hex: app},
          else: {app, "== #{@version}"}

      root ->
        {app, path: Path.join(root, Atom.to_string(app)), override: true}
    end
  end

  defp docs do
    [
      main: "GPUI.Display.Native",
      source_ref: "v#{@version}",
      filter_modules: &documented_module?/2,
      groups_for_modules: [
        Native: [GPUI.Display.Native, GPUI.Image]
      ]
    ]
  end

  defp documented_module?(module, _metadata),
    do: module in [GPUI.Display.Native, GPUI.Image]
end
