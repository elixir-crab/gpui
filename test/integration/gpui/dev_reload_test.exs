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
    Process.sleep(100)

    File.write!(path, source(module, "after"))

    assert_receive {:gpui_snapshot,
                    %{windows: [%{root: %{assigns: %{count: 7}, tree: after_tree}}]}},
                   5_000

    assert text(after_tree) == "after 7"
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

  defp temporary_source_path do
    Path.join(
      System.tmp_dir!(),
      "gpui-dev-reload-#{System.unique_integer([:positive])}.exs"
    )
  end

  defp text(%{children: [%{children: children}]}), do: Enum.join(children)
end
