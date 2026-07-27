GPUITest.Examples.load!(:elixir_workbench)

defmodule GPUITest.Visual.ElixirWorkbench.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :elixir_workbench

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.ElixirWorkbench.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: fixture()

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Elixir Workbench"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "repository-and-console"},
      %{name: "selected-diff", actions: [change("file_selected", "file:lib/gpui/runtime.ex")]},
      %{name: "command-palette", actions: [click("command-palette")]}
    ]
  end

  defp click(event), do: {:dispatch, %{type: :click, window_id: 1, event: event}}

  defp change(event, value),
    do: {:dispatch, %{type: :change, window_id: 1, event: event, value: value}}

  defp fixture do
    files = [
      file("README.md", :modified),
      file("lib/gpui.ex", :clean),
      file("lib/gpui/runtime.ex", :modified),
      file("lib/gpui/session.ex", :clean),
      file("lib/gpui/ui.ex", :modified),
      file("test/gpui/runtime_test.exs", :clean)
    ]

    repository = %{
      root: "/workspace/gpui",
      name: "gpui",
      branch: "main",
      files: files,
      counts: %{total: length(files), clean: 3, changed: 3}
    }

    previews = %{
      "README.md" =>
        preview("README.md", :file, :modified, [
          "# GPUI",
          "",
          "Elixir bindings for native GPUI applications."
        ]),
      "lib/gpui/runtime.ex" =>
        preview("lib/gpui/runtime.ex", :diff, :modified, [
          "@@ -78,6 +78,9 @@",
          " def request_frame(runtime) do",
          "+  with {:ok, snapshot} <- Session.refresh(session),",
          "+       :ok <- Display.sync(display, snapshot),",
          " end"
        ])
    }

    logs = [
      %{level: :info, source: "tests", message: "196 tests passed", timestamp: "12:14:02.118"},
      %{
        level: :warning,
        source: "compiler",
        message: "two diagnostics remain",
        timestamp: "12:14:03.402"
      },
      %{level: :info, source: "reload", message: "runtime.ex reloaded", timestamp: "12:14:05.817"}
    ]

    %{repository: repository, previews: previews, selected_path: "README.md", logs: logs}
  end

  defp file(path, status), do: %{path: path, name: Path.basename(path), status: status}

  defp preview(path, mode, status, lines) do
    %{
      path: path,
      mode: mode,
      status: status,
      lines:
        lines
        |> Enum.with_index(1)
        |> Enum.map(fn {text, number} ->
          kind =
            cond do
              String.starts_with?(text, "@@") -> :hunk
              String.starts_with?(text, "+") -> :addition
              true -> :context
            end

          %{id: "#{path}-#{number}", number: number, text: text, kind: kind}
        end)
    }
  end
end
