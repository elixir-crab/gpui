defmodule GPUI.Native.MixProject do
  use Mix.Project

  @version "0.2.0-dev"
  @source_url "https://github.com/dannote/gpui"

  def project do
    [
      app: :gpui_native,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "RustlerPrecompiled native GPUI hosts for GPUI.",
      source_url: @source_url,
      homepage_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_load_filters: [&load_test_file?/1],
      test_ignore_filters: [&ignore_test_file?/1]
    ]
  end

  def application, do: []

  defp elixirc_paths(env) when env in [:dev, :test, :e2e, :release],
    do: ["lib", Path.expand("../../dev", __DIR__)]

  defp elixirc_paths(_env), do: ["lib"]

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
      if File.exists?("checksum-Elixir.GPUI.Native.exs"),
        do: ["checksum-Elixir.GPUI.Native.exs" | files],
        else: files

    [
      name: "gpui_native",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: files,
      exclude_patterns: [~r{^native/target(?:/|$)}]
    ]
  end

  defp deps do
    [
      {:gpui, "== #{@version}", in_umbrella: true, hex: :gpui},
      {:gpui_components, "== #{@version}", in_umbrella: true, hex: :gpui_components},
      {:json_codec, "~> 0.2.3", only: [:dev, :test, :release], runtime: false},
      {:rustler, "~> 0.38.0", runtime: false},
      {:rustler_precompiled, "~> 0.9"}
    ]
  end
end
