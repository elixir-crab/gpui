GPUITest.Examples.load!(:elixir_workbench)

defmodule GPUI.ElixirWorkbenchExampleTest do
  use GPUI.Test, async: true

  test "combines repository navigation, code, logs, and commands" do
    runtime = start_runtime!(Examples.ElixirWorkbench.App, args: fixture())

    assert %{title: "Elixir Workbench", size: [1440, 900]} = window_snapshot(runtime)
    assert %{selected_id: "file:README.md", command_open: false} = assigns(runtime)
    assert %{type: :ui_tree} = runtime |> tree() |> find!(id: "workbench-tree")
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "workbench-code")
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "workbench-logs")

    change(runtime, "file_selected", "file:lib/gpui.ex")
    assert %{selected_id: "file:lib/gpui.ex", preview: %{path: "lib/gpui.ex"}} = assigns(runtime)

    change(runtime, "log_selected", "event-2")
    assert %{log_selected: "event-2"} = assigns(runtime)

    click(runtime, "command-palette")
    assert %{command_open: true} = assigns(runtime)
    click(runtime, "run-tests")
    assert %{command_open: false, last_command: "tests"} = assigns(runtime)
  end

  test "filters files and logs and clears the console" do
    runtime = start_runtime!(Examples.ElixirWorkbench.App, args: fixture())

    change(runtime, "filter_changed", "gpui")
    select(runtime, "status_changed", "modified")
    select(runtime, "log_level_changed", "warning")

    assert %{query: "gpui", status: "modified", log_level: "warning"} = assigns(runtime)

    click(runtime, "clear-logs")
    assert %{logs: [], log_selected: nil} = assigns(runtime)
  end

  defp fixture do
    files = [
      %{path: "README.md", name: "README.md", status: :modified},
      %{path: "lib/gpui.ex", name: "gpui.ex", status: :modified},
      %{path: "test/gpui_test.exs", name: "gpui_test.exs", status: :clean}
    ]

    repository = %{
      root: "/workspace/gpui",
      name: "gpui",
      branch: "main",
      files: files,
      counts: %{total: 3, clean: 1, changed: 2}
    }

    previews = %{
      "README.md" => preview("README.md", :file, :modified, ["# GPUI", "Elixir bindings"]),
      "lib/gpui.ex" =>
        preview("lib/gpui.ex", :diff, :modified, ["@@ -1,2 +1,3 @@", "+def hello, do: :world"])
    }

    logs = [
      %{level: :info, source: "tests", message: "166 tests passed", timestamp: "12:00:00.000"},
      %{level: :warning, source: "compiler", message: "unused alias", timestamp: "12:00:01.000"}
    ]

    %{repository: repository, previews: previews, selected_path: "README.md", logs: logs}
  end

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
            if String.starts_with?(text, "+"),
              do: :addition,
              else: if(String.starts_with?(text, "@@"), do: :hunk, else: :context)

          %{id: "#{path}-#{number}", number: number, text: text, kind: kind}
        end)
    }
  end
end
