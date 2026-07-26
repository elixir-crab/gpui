Code.require_file(
  "../../examples/git_repository_browser/support/git_repository_browser.exs",
  __DIR__
)

defmodule GPUI.GitRepositoryBrowserExampleTest.FakeRepository do
  def scan(path, opts) do
    send(opts[:owner], {:repository_scan_started, path, self()})
    {:ok, opts[:repository]}
  end

  def preview(_repository, path, opts) do
    if path == "lib/slow.ex" do
      send(opts[:owner], {:slow_preview_started, self()})

      receive do
        :finish -> {:ok, opts[:previews][path]}
      end
    else
      {:ok, opts[:previews][path]}
    end
  end
end

defmodule GPUI.GitRepositoryBrowserExampleTest do
  use GPUI.Test, async: false

  alias Examples.GitRepositoryBrowser.App
  alias Examples.GitRepositoryBrowser.Coordinator
  alias Examples.GitRepositoryBrowser.Model
  alias Examples.GitRepositoryBrowser.Repository
  alias Examples.GitRepositoryBrowser.Tree
  alias GPUI.GitRepositoryBrowserExampleTest.FakeRepository

  test "scans real Git status and returns bounded diff and file previews" do
    root = repository_fixture!()

    assert {:ok, repository} = Repository.scan(root)
    assert File.stat!(repository.root).inode == File.stat!(root).inode
    assert repository.branch == "main"
    assert repository.counts == %{total: 5, clean: 1, changed: 4}

    assert Enum.find(repository.files, &(&1.path == "README.md")).status == :modified
    assert Enum.find(repository.files, &(&1.path == "lib/new.ex")).status == :untracked
    assert Enum.find(repository.files, &(&1.path == "lib/renamed.ex")).status == :renamed
    assert Enum.find(repository.files, &(&1.path == "test/old_test.exs")).status == :deleted

    assert {:ok, %{mode: :diff, status: :modified, lines: lines}} =
             Repository.preview(repository, "README.md")

    assert Enum.any?(lines, &(&1.kind == :added and String.contains?(&1.text, "changed")))
    assert Enum.any?(lines, &(&1.kind == :deleted and String.contains?(&1.text, "initial")))

    assert {:ok, %{mode: :file, status: :clean, lines: clean_lines}} =
             Repository.preview(repository, "lib/clean.ex")

    assert Enum.any?(clean_lines, &String.contains?(&1.text, "defmodule Clean"))

    assert {:ok, %{mode: :file, status: :untracked, lines: untracked_lines}} =
             Repository.preview(repository, "lib/new.ex")

    assert Enum.any?(untracked_lines, &String.contains?(&1.text, "defmodule New"))

    assert {:error, "invalid repository-relative path"} =
             Repository.preview(repository, "../secret")
  end

  test "bounds and classifies working-tree file previews" do
    repository = repository()
    git = fn _root, _args, _limit -> {:ok, ""} end

    assert {:ok, %{mode: :notice, lines: [%{kind: :notice, text: oversized}]}} =
             Repository.preview(repository, "lib/slow.ex",
               git: git,
               read: fn _path, limit -> {:ok, :binary.copy("x", limit + 1)} end
             )

    assert oversized =~ "preview limit"

    assert {:ok, %{mode: :notice, lines: [%{text: binary_notice}]}} =
             Repository.preview(repository, "lib/slow.ex",
               git: git,
               read: fn _path, _limit -> {:ok, <<0, 1, 2>>} end
             )

    assert binary_notice == "Binary file preview is unavailable."
  end

  test "flattens expandable hierarchy while filtering by path and status" do
    repository = repository()
    expanded = MapSet.new(["lib"])

    entries = Tree.visible(repository.files, expanded, "", "all")

    assert Enum.map(entries, & &1.id) == [
             "dir:lib",
             "dir:lib/core",
             "file:lib/slow.ex",
             "dir:test"
           ]

    entries = Tree.visible(repository.files, MapSet.put(expanded, "lib/core"), "", "all")
    assert Enum.any?(entries, &(&1.id == "file:lib/core/worker.ex"))

    entries = Tree.visible(repository.files, expanded, "worker", "modified")
    assert Enum.map(entries, & &1.id) == ["dir:lib", "dir:lib/core"]
  end

  test "controls tree expansion, filters, and virtualized previews deterministically" do
    repository = repository()
    preview = preview("lib/core/worker.ex", :modified, :diff, 2_000)

    runtime =
      start_gpui!(App,
        args: %{
          repository: repository,
          selected_path: "lib/core/worker.ex",
          preview: preview,
          expanded: MapSet.new(["lib", "lib/core", "test"])
        }
      )

    assert %{type: :ui_tree} = runtime |> tree() |> find!(id: "repository-tree")
    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "preview-lines")
    refute Map.has_key?(assigns(runtime).repository, :files)
    refute Map.has_key?(assigns(runtime).preview, :lines)
    assert assigns(runtime).preview.max_columns > 0
    assert runtime |> tree() |> all(type: :ui_tree_item) |> length() < 100
    assert runtime |> tree() |> all(type: :ui_code_line) |> length() < 100
    assert runtime |> tree() |> all(id: "line-1501") == []

    range(runtime, "preview_range_changed", 1_500, 1_550)

    send_view(
      runtime,
      {:preview_slice, 1, Model.preview_slice(preview, %{first: 1_500, last: 1_550})}
    )

    assert runtime |> tree() |> all(id: "line-1501") |> length() == 1
    assert runtime |> tree() |> all(id: "line-1") == []

    select(runtime, "preview_line_selected", "line-1501")
    assert %{preview_selected_id: "line-1501", preview_selected_index: 1_500} = assigns(runtime)

    copy_selected_line(runtime, "preview_line_copied")
    assert %{preview_copy_count: 1} = assigns(runtime)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(
             &match?(%{children: ["Copied selected line · Ctrl/Cmd+C to copy again"]}, &1)
           )

    select(runtime, "tree_toggled", "dir:lib/core")
    assigns = assigns(runtime)

    send_view(
      runtime,
      {:tree_slice, 1,
       Model.tree_slice(
         repository,
         assigns.expanded,
         assigns.filter,
         assigns.status_filter,
         assigns.tree_range,
         assigns.selected_id
       )}
    )

    refute runtime |> tree() |> all(id: "file:lib/core/worker.ex") |> Enum.any?()

    change(runtime, "status_filter_changed", "untracked")
    assigns = assigns(runtime)

    send_view(
      runtime,
      {:tree_slice, 2,
       Model.tree_slice(
         repository,
         assigns.expanded,
         assigns.filter,
         assigns.status_filter,
         assigns.tree_range,
         assigns.selected_id
       )}
    )

    assert runtime |> tree() |> all(id: "file:test/new_test.exs") |> Enum.any?()
    refute runtime |> tree() |> all(id: "file:lib/slow.ex") |> Enum.any?()

    command(runtime, "focus_repository_filter")
    assert %{filter_focus_request: 1} = assigns(runtime)

    command(runtime, "reload_repository")
    assert %{scan_status: :scanning} = assigns(runtime)
  end

  test "supervises scans and replaces an active preview without stale results" do
    repository = repository()

    previews = %{
      "lib/slow.ex" => preview("lib/slow.ex", :clean, :file, 2),
      "lib/core/worker.ex" => preview("lib/core/worker.ex", :modified, :diff, 3)
    }

    runtime = start_gpui!(App, args: %{path: "/server/repository"})
    task_supervisor = start_task_supervisor!()

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator,
         runtime: runtime,
         path: "/server/repository",
         task_supervisor: task_supervisor,
         repository_module: FakeRepository,
         repository_opts: [owner: self(), repository: repository, previews: previews],
         owner: self()},
        id: make_ref()
      )
    )

    assert_receive {:repository_scan_started, "/server/repository", _task}
    assert_receive {:git_repository_browser, :loaded, 1}
    assert %{scan_status: :ready, repository: %{branch: "main"}} = assigns(runtime)

    select(runtime, "tree_selected", "file:lib/slow.ex")
    assert_receive {:slow_preview_started, slow_task}
    monitor = Process.monitor(slow_task)

    select(runtime, "tree_selected", "file:lib/core/worker.ex")
    assert_receive {:DOWN, ^monitor, :process, ^slow_task, :killed}
    assert_receive {:git_repository_browser, :previewed, 2}

    assert %{
             selected_path: "lib/core/worker.ex",
             preview_status: :ready,
             preview: %{path: "lib/core/worker.ex"}
           } = assigns(runtime)

    send_view(runtime, {:preview_loaded, 1, previews["lib/slow.ex"]})
    assert %{preview: %{path: "lib/core/worker.ex"}} = assigns(runtime)

    click(runtime, "reload_repository")
    assert_receive {:repository_scan_started, "/server/repository", _refresh_task}
    assert_receive {:git_repository_browser, :loaded, 2}
    assert_receive {:git_repository_browser, :previewed, 3}

    assert %{
             scan_status: :ready,
             preview_status: :ready,
             preview_job: 3,
             preview: %{path: "lib/core/worker.ex"}
           } = assigns(runtime)

    preview_generation = assigns(runtime).preview_generation + 1
    range(runtime, "preview_range_changed", 1, 3)
    assert_receive {:git_repository_browser, :preview_slice, ^preview_generation}

    assert %{preview_offset: 1, preview_lines: [%{id: "line-2"}, %{id: "line-3"}]} =
             assigns(runtime)

    tree_generation = assigns(runtime).tree_generation + 1
    change(runtime, "status_filter_changed", "untracked")
    assert_receive {:git_repository_browser, :tree_slice, ^tree_generation}

    assert %{tree_total: 2, tree_items: [%{id: "dir:test"}, %{status: :untracked}]} =
             assigns(runtime)
  end

  defp start_task_supervisor! do
    start_supervised!(Supervisor.child_spec({Task.Supervisor, []}, id: make_ref()))
  end

  defp repository do
    files = [
      %{path: "lib/core/worker.ex", name: "worker.ex", status: :modified},
      %{path: "lib/slow.ex", name: "slow.ex", status: :clean},
      %{path: "test/new_test.exs", name: "new_test.exs", status: :untracked}
    ]

    %{
      root: "/server/repository",
      name: "repository",
      branch: "main",
      files: files,
      counts: %{total: 3, clean: 1, changed: 2}
    }
  end

  defp preview(path, status, mode, line_count) do
    lines =
      for number <- 1..line_count do
        %{
          id: "line-#{number}",
          number: number,
          text:
            if(rem(number, 2) == 0, do: "+changed line #{number}", else: " context #{number}"),
          kind: if(rem(number, 2) == 0, do: :added, else: :context)
        }
      end

    %{path: path, status: status, mode: mode, lines: lines}
  end

  defp repository_fixture! do
    root =
      Path.join(System.tmp_dir!(), "gpui-git-browser-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "lib"))
    File.mkdir_p!(Path.join(root, "test"))
    File.write!(Path.join(root, "README.md"), "initial\n")
    File.write!(Path.join(root, "lib/clean.ex"), "defmodule Clean do\nend\n")
    File.write!(Path.join(root, "lib/rename_me.ex"), "defmodule RenameMe do\nend\n")
    File.write!(Path.join(root, "test/old_test.exs"), "old test\n")

    git!(root, ["init", "-b", "main"])
    git!(root, ["config", "user.email", "gpui@example.test"])
    git!(root, ["config", "user.name", "GPUI Test"])
    git!(root, ["add", "."])
    git!(root, ["commit", "-m", "initial"])

    File.write!(Path.join(root, "README.md"), "changed\n")
    File.write!(Path.join(root, "lib/new.ex"), "defmodule New do\nend\n")
    git!(root, ["mv", "lib/rename_me.ex", "lib/renamed.ex"])
    File.rm!(Path.join(root, "test/old_test.exs"))

    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  defp git!(root, args) do
    case System.cmd("git", ["-C", root | args], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> flunk("git command failed (#{status}): #{output}")
    end
  end
end
