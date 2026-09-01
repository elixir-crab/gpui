defmodule GPUI.ReleaseTools.MixProject do
  use Mix.Project

  def project do
    [
      app: :gpui_release_tools,
      version: "0.1.0",
      build_path: "../../_build/release_tools",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      elixirc_paths: [
        Path.expand("../gpui/release", __DIR__),
        Path.expand("../mix/tasks/gpui/release/changelog", __DIR__),
        Path.expand("../mix/tasks/gpui/release/glibc", __DIR__),
        Path.expand("../mix/tasks/gpui/release/version", __DIR__)
      ],
      deps: []
    ]
  end
end
