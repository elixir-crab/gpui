defmodule GPUI.ReleaseTools.MixProject do
  use Mix.Project

  @workspace_markers ["mix.exs", "Cargo.toml", "apps", "dev"]

  @workspace_root __DIR__
                  |> Path.expand()
                  |> Stream.unfold(fn path ->
                    parent = Path.dirname(path)
                    {path, if(parent == path, do: nil, else: parent)}
                  end)
                  |> Enum.find(fn path ->
                    Enum.all?(@workspace_markers, &File.exists?(Path.join(path, &1)))
                  end)
                  |> Kernel.||(raise "could not locate the GPUI workspace root")

  @maintainer_root Path.join(@workspace_root, "dev/gpui/maintainer")
  @release_tasks_root Path.join(@workspace_root, "dev/mix/tasks/gpui/release")

  def project do
    [
      app: :gpui_release_tools,
      version: "0.1.0",
      build_path: Path.join(@workspace_root, "_build/release_tools"),
      deps_path: Path.join(@workspace_root, "deps"),
      lockfile: Path.join(@workspace_root, "mix.lock"),
      elixir: "~> 1.20",
      elixirc_paths: [
        Path.join(@maintainer_root, "release"),
        Path.join(@maintainer_root, "paths.ex"),
        Path.join(@release_tasks_root, "archive"),
        Path.join(@release_tasks_root, "changelog"),
        Path.join(@release_tasks_root, "glibc"),
        Path.join(@release_tasks_root, "version")
      ],
      deps: []
    ]
  end
end
