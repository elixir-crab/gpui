defmodule GPUI.Native.SplitE2ETest do
  use ExUnit.Case, async: false

  alias GPUI.UI
  alias GPUITest.Desktop

  @moduletag :e2e

  defmodule View do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      UI.split(%{
        :"phx-change" => "split_resized",
        id: "native-split",
        class: "w-full h-full",
        sizes: assigns.sizes,
        min_sizes: [140, 240],
        resize_request: assigns.resize_request,
        children: [
          %GPUI.Element{type: :div, attrs: [class: "w-full h-full"], children: ["First"]},
          %GPUI.Element{type: :div, attrs: [class: "w-full h-full"], children: ["Second"]}
        ]
      })
    end

    @impl GPUI.View
    def handle_event("split_resized", %{value: [first, second] = sizes}, assigns)
        when is_number(first) and is_number(second),
        do: {:noreply, %{assigns | sizes: sizes}}
  end

  defmodule App do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(800, 480)
           root(View, sizes: [260, 540], resize_request: 0)
         end
       ]}
    end
  end

  test "native divider drag emits bounded pane sizes without resetting on rerender" do
    title = "GPUI Split E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: App, args: %{title: title})
    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    native_window = Desktop.window_id!(title)
    Desktop.await_frame!(runtime, 1, native_window)

    Desktop.drag!(native_window, 260, 200, 360, 200)

    resized =
      Desktop.eventually(fn ->
        %{windows: [%{root: %{assigns: %{sizes: [first, second] = sizes}}}]} =
          GPUI.Runtime.snapshot(runtime)

        assert first >= 140
        assert second >= 240
        assert first > 300
        sizes
      end)

    assert {:ok, _snapshot} = GPUI.Runtime.refresh(runtime)
    assert %{windows: [%{root: %{assigns: %{sizes: ^resized}}}]} = GPUI.Runtime.snapshot(runtime)
  end
end
