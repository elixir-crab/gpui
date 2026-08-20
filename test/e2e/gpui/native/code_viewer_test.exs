defmodule GPUI.Native.CodeViewerE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  @moduletag :e2e

  defmodule SourceCodeView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      first = min(assigns.range.first, assigns.total_count)
      last = assigns.range.last |> max(first) |> min(assigns.total_count)

      lines =
        if first < last do
          Enum.map(first..(last - 1), &line(&1, assigns.total_count))
        else
          []
        end

      ~GPUI"""
      <div class="w-[640px] h-[420px] bg-slate-900">
        <UI.code_viewer
          id="source-code"
          label="Large source file"
          mode="diff"
          total_count={assigns.total_count}
          offset={first}
          overscan={10}
          item_height={24}
          max_columns={600}
          selected={assigns.selected}
          selected_index={assigns.selected_index}
          reveal={assigns.reveal}
          reveal_index={assigns.reveal_index}
          phx-change="line_selected"
          phx-range="code_range"
          phx-copy="line_copied"
          class="h-[400px]"
        >
          {lines}
        </UI.code_viewer>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("code_range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("line_selected", %{value: "line-" <> number = selected}, assigns) do
      index = String.to_integer(number) - 1

      {:noreply,
       %{
         assigns
         | selected: selected,
           selected_index: index,
           reveal: selected,
           reveal_index: index
       }}
    end

    def handle_event("line_copied", _event, assigns),
      do: {:noreply, %{assigns | copies: assigns.copies + 1}}

    defp line(index, total_count) do
      number = index + 1

      text =
        if number == total_count,
          do: "+" <> String.duplicate("long-line-", 60),
          else: " line #{number}"

      kind = if rem(number, 3) == 0, do: "addition", else: "context"
      assigns = %{id: "line-#{number}", number: number, text: text, kind: kind}

      ~GPUI"""
      <UI.code_line
        id={assigns.id}
        number={assigns.number}
        text={assigns.text}
        kind={assigns.kind}
      />
      """
    end
  end

  defmodule SourceCodeApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Code Viewer E2E" do
           size(640, 420)

           root(SourceCodeView,
             total_count: 100_000,
             range: %{first: 0, last: 40},
             selected: "line-100000",
             selected_index: 99_999,
             reveal: "line-100000",
             reveal_index: 99_999,
             copies: 0
           )
         end
       ]}
    end
  end

  test "virtualizes, reveals, navigates, copies, and horizontally scrolls long code" do
    {:ok, runtime} = GPUI.Runtime.start_link(app: SourceCodeApp, poll_interval: 10)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    window_id = Desktop.window_id!("GPUI Code Viewer E2E")
    Desktop.await_frame!(runtime, 1, window_id)

    range = current_or_await_distant_range(runtime)
    assert range.first > 99_900
    assert range.last == 100_000
    Desktop.await_frame!(runtime, 1, window_id)

    snapshot = GPUI.Runtime.snapshot(runtime)
    assigns = snapshot.windows |> hd() |> get_in([:root, :assigns])
    assert assigns.total_count == 100_000
    refute Map.has_key?(assigns, :lines)

    loaded_lines = snapshot |> GPUI.Test.tree() |> GPUI.Test.all(type: :ui_code_line)
    assert Enum.count(loaded_lines) <= 40
    assert Enum.any?(loaded_lines, &match?(%{attrs: %{id: "line-100000"}}, &1))

    Desktop.click!(window_id, 120, 200)
    clicked = await_selection(runtime)

    Desktop.key!(window_id, "Up")
    previous = await_selection(runtime)
    assert line_number(previous) == line_number(clicked) - 1

    Desktop.key!(window_id, "Page_Up")
    paged = await_selection(runtime)
    assert line_number(paged) < line_number(previous)

    Desktop.key!(window_id, "ctrl+c")

    assert_receive {:gpui, ^runtime, %GPUI.Runtime.Update{events: [%{event: "line_copied"}]}},
                   5_000

    assert root_assigns(runtime).copies == 1

    Desktop.repeat_click!(window_id, 500, 200, 20)
    assert :ok = GPUI.Runtime.request_frame(runtime)
    Desktop.await_frame!(runtime, 1, window_id)
    assert Process.alive?(runtime)
  end

  defp current_or_await_distant_range(runtime) do
    range = root_assigns(runtime).range
    if range.last > 99_900, do: range, else: await_range(runtime)
  end

  defp await_range(runtime) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{event: "code_range", value: %{first: first, last: last}}
               when last > 99_900 ->
                 %{first: first, last: last}

               _event ->
                 nil
             end) do
          nil -> await_range(runtime)
          range -> range
        end
    after
      5_000 -> flunk("code viewer did not request the distant source range")
    end
  end

  defp await_selection(runtime) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{event: "line_selected", value: selected} -> selected
               _event -> nil
             end) do
          nil -> await_selection(runtime)
          selected -> selected
        end
    after
      5_000 -> flunk("code viewer did not emit a selection")
    end
  end

  defp root_assigns(runtime) do
    runtime
    |> GPUI.Runtime.snapshot()
    |> Map.fetch!(:windows)
    |> hd()
    |> get_in([:root, :assigns])
  end

  defp line_number("line-" <> number), do: String.to_integer(number)
end
