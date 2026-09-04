defmodule GPUI.Native.CodeViewerE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

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

  test "desktop renders a distant virtualized code range", %{desktop: desktop} do
    runtime = start_runtime!(desktop, app: SourceCodeApp, poll_interval: 10)
    window = Desktop.window!(desktop, "GPUI Code Viewer E2E")
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert root_assigns(runtime).range.last > 99_900
    assert Process.alive?(runtime)
  end

  defp root_assigns(runtime) do
    runtime
    |> GPUI.Runtime.snapshot()
    |> Map.fetch!(:windows)
    |> hd()
    |> get_in([:root, :assigns])
  end
end
