defmodule GPUI.DevTest do
  use ExUnit.Case, async: false

  defmodule ReloadApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(args) do
      view = Map.fetch!(Map.new(args), :view)

      {:ok,
       [
         window "Reload" do
           root(view, count: 7)
         end
       ]}
    end
  end

  test "reloads a changed source file and preserves window assigns" do
    path = temporary_source_path()
    module = Module.concat(__MODULE__, "Reloaded#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    File.write!(path, source(module, "before"))
    Code.compile_file(path)

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: ReloadApp,
        args: %{view: module},
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, %{windows: [%{root: %{tree: before_tree}}]}}
    assert text(before_tree) == "before 7"

    {:ok, watcher} = GPUI.Dev.watch(runtime, files: [path], debounce: 10)
    assert Process.alive?(watcher)
    Process.sleep(750)
    flush_snapshots()

    File.write!(path, source(module, "after"))

    assert_receive {:gpui_snapshot,
                    %{windows: [%{root: %{assigns: %{count: 7}, tree: after_tree}}]}},
                   5_000

    assert text(after_tree) == "after 7"
  end

  test "reload preserves dynamic topology, IDs, assigns, and monotonic allocation" do
    path = temporary_source_path()
    module = Module.concat(__MODULE__, "Dynamic#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    File.write!(path, dynamic_source(module, "before", 1))
    Code.compile_file(path)

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: ReloadApp,
        args: %{view: module},
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, %{windows: [%{id: 1}]}}

    {_event, %{windows: [_, %{id: 2, key: "details"}]}} =
      dispatch(runtime, 1, "open-details")

    {_event, _snapshot} = dispatch(runtime, 1, "increment")
    {_event, _snapshot} = dispatch(runtime, 2, "increment")

    {_event, %{windows: [_, _, %{id: 3, key: "transient"}]}} =
      dispatch(runtime, 1, "open-transient")

    {_event, %{windows: [%{id: 1}, %{id: 2}]}} = dispatch(runtime, 1, "close-transient")

    {:ok, watcher} = GPUI.Dev.watch(runtime, files: [path], debounce: 10)
    assert Process.alive?(watcher)
    Process.sleep(750)
    flush_snapshots()
    File.write!(path, dynamic_source(module, "after", 10))

    assert_receive {:gpui_snapshot, %{windows: [main, details]}}, 5_000
    assert %{id: 1, key: nil, root: %{assigns: %{count: 8}, tree: main_tree}} = main
    assert %{id: 2, key: "details", root: %{assigns: %{count: 1}, tree: details_tree}} = details
    assert text(main_tree) == "after main8"
    assert text(details_tree) == "after details1"

    {_event, %{windows: [_, updated_details]}} = dispatch(runtime, 2, "increment")
    assert updated_details.root.assigns.count == 11

    {_event, %{windows: [_, _, reopened]}} = dispatch(runtime, 1, "open-transient")
    assert %{id: 4, key: "transient"} = reopened
  end

  test "reload failures are observable, preserve the live session, and recover" do
    path = temporary_source_path()
    module = Module.concat(__MODULE__, "Recoverable#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    File.write!(path, dynamic_source(module, "working", 1))
    Code.compile_file(path)

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: ReloadApp,
        args: %{view: module},
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, %{windows: [%{id: 1}]}}
    {_event, %{windows: [_, %{id: 2}]}} = dispatch(runtime, 1, "open-details")

    {:ok, watcher} = GPUI.Dev.watch(runtime, files: [path], debounce: 10, notify: self())
    Process.sleep(750)
    flush_snapshots()
    File.write!(path, "defmodule #{inspect(module)} do\n  def render(\nend")

    assert_receive {:gpui_reload, ^watcher, _canonical_path,
                    {:error, {:compile_failed, :error, error}}},
                   5_000

    assert is_exception(error)

    assert Process.alive?(watcher)
    refute_receive {:gpui_snapshot, _snapshot}, 100
    assert %{windows: [%{id: 1}, %{id: 2}]} = GPUI.Runtime.snapshot(runtime)

    {_event, %{windows: [%{root: %{assigns: %{count: 8}}}, _]}} =
      dispatch(runtime, 1, "increment")

    flush_snapshots()
    File.write!(path, dynamic_source(module, "recovered", 10))

    assert_receive {:gpui_reload, ^watcher, _canonical_path, {:ok, [^module]}}, 5_000
    assert_receive {:gpui_snapshot, %{windows: [main, details]}}, 5_000
    assert text(main.root.tree) == "recovered main8"
    assert text(details.root.tree) == "recovered details0"
  end

  test "runtime refresh failure publishes nothing and retains every dynamic window" do
    path = temporary_source_path()
    module = Module.concat(__MODULE__, "Atomic#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    File.write!(path, selective_source(module, false))
    Code.compile_file(path)

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: ReloadApp,
        args: %{view: module},
        display: GPUI.Test.Display,
        display_opts: [owner: self()],
        poll_interval: nil
      )

    assert_receive {:gpui_snapshot, _snapshot}
    {_event, %{windows: [_, %{id: 2}]}} = dispatch(runtime, 1, "open-details")
    assert :ok = GPUI.Runtime.subscribe(runtime)
    flush_snapshots()

    File.write!(path, selective_source(module, true))
    Code.compile_file(path)

    assert {:error, {:render_failed, %RuntimeError{message: "details failed"}, _stacktrace}} =
             GPUI.Runtime.refresh(runtime)

    refute_receive {:gpui_snapshot, _snapshot}, 100
    refute_receive {:gpui, ^runtime, %GPUI.Runtime.Update{}}, 100
    assert [window_one, window_two] = GPUI.Runtime.windows(runtime)
    assert window_one.id == 1
    assert window_two.id == 2

    File.write!(path, selective_source(module, false))
    Code.compile_file(path)
    assert {:ok, %{windows: [%{id: 1}, %{id: 2}]}} = GPUI.Runtime.refresh(runtime)
  end

  defp source(module, prefix) do
    """
    defmodule #{inspect(module)} do
      use GPUI.View

      @impl GPUI.View
      def render(assigns) do
        ~GPUI\"\"\"
        <text>#{prefix} {assigns.count}</text>
        \"\"\"
      end
    end
    """
  end

  defp selective_source(module, fail_details?) do
    failing_clause =
      if fail_details? do
        """
        def render(%{label: "details"}) do
          raise "details failed"
        end
        """
      else
        ""
      end

    """
    defmodule #{inspect(module)} do
      use GPUI.View

      #{failing_clause}
      @impl GPUI.View
      def render(assigns) do
        ~GPUI\"\"\"
        <text>stable {Map.get(assigns, :label, "main")} {assigns.count}</text>
        \"\"\"
      end

      @impl GPUI.View
      def handle_event("open-details", _event, assigns) do
        window = %GPUI.WindowSpec{
          key: "details",
          title: "Details",
          root: {__MODULE__, %{label: "details", count: 0}}
        }

        {:open_window, window, assigns}
      end
    end
    """
  end

  defp dynamic_source(module, prefix, increment) do
    """
    defmodule #{inspect(module)} do
      use GPUI.View

      @impl GPUI.View
      def render(assigns) do
        ~GPUI\"\"\"
        <text>#{prefix} {Map.get(assigns, :label, "main")} {assigns.count}</text>
        \"\"\"
      end

      @impl GPUI.View
      def handle_event("increment", _event, assigns) do
        {:noreply, Map.update!(assigns, :count, &(&1 + #{increment}))}
      end

      def handle_event("open-details", _event, assigns) do
        window = %GPUI.WindowSpec{
          key: "details",
          title: "Details",
          root: {__MODULE__, %{label: "details", count: 0}}
        }

        {:open_window, window, assigns}
      end

      def handle_event("open-transient", _event, assigns) do
        window = %GPUI.WindowSpec{
          key: "transient",
          title: "Transient",
          root: {__MODULE__, %{label: "transient", count: 0}}
        }

        {:open_window, window, assigns}
      end

      def handle_event("close-transient", _event, assigns) do
        {:close_window, "transient", assigns}
      end
    end
    """
  end

  defp dispatch(runtime, window_id, event) do
    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: window_id,
      event: event
    })
  end

  defp flush_snapshots do
    receive do
      {:gpui_snapshot, _snapshot} -> flush_snapshots()
    after
      0 -> :ok
    end
  end

  defp temporary_source_path do
    Path.join(
      System.tmp_dir!(),
      "gpui-dev-reload-#{System.unique_integer([:positive])}.exs"
    )
  end

  defp text(%{children: [%{children: children}]}), do: Enum.join(children)
end
