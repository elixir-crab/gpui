GPUITest.Examples.load!(:elixir_workbench)

defmodule GPUI.Native.ElixirWorkbenchRepositorySourceE2ETest do
  use ExUnit.Case, async: false

  alias Examples.ElixirWorkbench.RepositoryApp, as: App
  alias GPUITest.Desktop

  @moduletag :e2e

  test "renders large repository and diff collections through native virtualization" do
    repository = repository(2_000)
    selected_path = "src/file-0010.ex"

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: App,
        args: %{
          repository: repository,
          selected_path: selected_path,
          preview: preview(selected_path, 5_000),
          expanded: MapSet.new(["src"])
        }
      )

    on_exit(fn -> Desktop.stop_process(runtime) end)

    native_window_id = Desktop.window_id!("Repository Workspace")
    Desktop.await_frame!(runtime, 1, native_window_id)

    assert %{
             preview: preview,
             preview_total: 5_000,
             preview_lines: preview_lines,
             selected_path: ^selected_path,
             tree_items: tree_items
           } = root_assigns(runtime)

    refute Map.has_key?(preview, :lines)
    assert Enum.count(preview_lines) <= 48
    assert Enum.count(tree_items) <= 48
    assert Process.alive?(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :change,
      window_id: 1,
      event: "status_filter_changed",
      value: "untracked"
    })

    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{status_filter: "untracked"} = root_assigns(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: 1,
      event: "reload_repository"
    })

    Desktop.await_frame!(runtime, 1, native_window_id)
    assert %{scan_status: :scanning, scan_id: 2} = root_assigns(runtime)
    assert Process.alive?(runtime)
  end

  defp root_assigns(runtime) do
    runtime
    |> GPUI.Runtime.snapshot()
    |> Map.fetch!(:windows)
    |> hd()
    |> get_in([:root, :assigns])
  end

  defp repository(count) do
    files =
      for number <- 1..count do
        path = "src/file-#{String.pad_leading(Integer.to_string(number), 4, "0")}.ex"
        status = if rem(number, 10) == 0, do: :untracked, else: :clean
        %{path: path, name: Path.basename(path), status: status}
      end

    %{
      root: "/fixtures/large-repository",
      name: "large-repository",
      branch: "main",
      files: files,
      counts: %{total: count, clean: count - div(count, 10), changed: div(count, 10)}
    }
  end

  defp preview(path, count) do
    lines =
      for number <- 1..count do
        kind = if rem(number, 3) == 0, do: :added, else: :context

        %{
          id: "line-#{number}",
          number: number,
          text: if(kind == :added, do: "+line #{number}", else: " line #{number}"),
          kind: kind
        }
      end

    %{path: path, status: :clean, mode: :file, lines: lines}
  end
end
