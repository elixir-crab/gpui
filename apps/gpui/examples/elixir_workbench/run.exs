Code.require_file("support/elixir_workbench.exs", __DIR__)

alias Examples.ElixirWorkbench.Repository

path =
  System.argv()
  |> Enum.reject(&(&1 == "--"))
  |> List.first()
  |> then(&if(&1, do: Path.expand(&1), else: File.cwd!()))

{:ok, repository} = Repository.scan(path)

preview_paths =
  repository.files
  |> Enum.reject(&(&1.status == :deleted))
  |> Enum.take(20)
  |> Enum.map(& &1.path)

previews =
  Map.new(preview_paths, fn relative_path ->
    preview =
      case Repository.preview(repository, relative_path) do
        {:ok, preview} ->
          preview

        {:error, reason} ->
          %{
            path: relative_path,
            mode: :notice,
            status: :clean,
            lines: [%{id: "error", number: nil, text: reason, kind: :notice}]
          }
      end

    {relative_path, preview}
  end)

selected_path = preview_paths |> List.first()

logs = [
  %{
    level: :info,
    source: "workbench",
    message: "Repository scan complete",
    timestamp: "12:14:02.118"
  },
  %{
    level: :warning,
    source: "compiler",
    message: "Two files have warnings",
    timestamp: "12:14:03.402"
  },
  %{level: :info, source: "tests", message: "166 tests passed", timestamp: "12:14:05.817"}
]

runtime = Examples.ElixirWorkbench.Runtime

{:ok, _runtime} =
  GPUI.Runtime.start_link(
    name: runtime,
    app: Examples.ElixirWorkbench.App,
    args: %{repository: repository, previews: previews, selected_path: selected_path, logs: logs}
  )

IO.puts("Elixir Workbench is inspecting #{path}. Press Ctrl+C twice to exit.")

GPUI.Dev.wait(runtime,
  files: [
    Path.join(__DIR__, "support/repository_source.exs"),
    Path.join(__DIR__, "support/repository_workspace_source.exs"),
    Path.join(__DIR__, "support/event_source.exs"),
    Path.join(__DIR__, "support/log_source.exs"),
    Path.join(__DIR__, "support/elixir_workbench.exs")
  ]
)
