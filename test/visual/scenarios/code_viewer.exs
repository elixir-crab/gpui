defmodule GPUITest.Visual.CodeViewer.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    lines = lines(assigns.mode)

    ~GPUI"""
    <div class="flex flex-col w-[720px] h-[480px] gap-3 p-4 bg-slate-900">
      <text class="text-white text-2xl font-semibold">Source-backed code viewer</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{subtitle(assigns.mode)}</text>
      <UI.code_viewer
        id="visual-code"
        label="Visual source code"
        mode={viewer_mode(assigns.mode)}
        selected={assigns.selected}
        reveal={assigns.selected}
        item_height={26}
        max_columns={160}
        tab_width={4}
        phx-change="line_selected"
        class="h-[390px]"
      >
        {Enum.map(lines, &code_line/1)}
      </UI.code_viewer>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("line_selected", %{value: selected}, assigns),
    do: {:noreply, %{assigns | selected: selected}}

  @impl GPUI.View
  def handle_info({:mode, mode}, assigns),
    do: {:noreply, %{assigns | mode: mode, selected: nil}}

  def handle_info({:long_line, selected}, assigns),
    do: {:noreply, %{assigns | mode: :long, selected: selected}}

  defp code_line(line) do
    UI.code_line(%{
      id: line.id,
      number: line.number,
      text: line.text,
      kind: line.kind
    })
  end

  defp lines(:code) do
    [
      %{id: "code-1", number: 1, text: "defmodule Report do", kind: "context"},
      %{id: "code-2", number: 2, text: "\talias GPUI.UI", kind: "context"},
      %{id: "code-3", number: 3, text: "", kind: "context"},
      %{id: "code-4", number: 4, text: "\tdef render(assigns) do", kind: "context"},
      %{id: "code-5", number: 5, text: "\t\tUI.code_viewer(assigns)", kind: "context"},
      %{id: "code-6", number: 6, text: "\tend", kind: "context"},
      %{id: "code-7", number: 7, text: "end", kind: "context"}
    ]
  end

  defp lines(:diff) do
    [
      %{
        id: "diff-1",
        number: nil,
        text: "@@ -18,6 +18,8 @@ def render(assigns) do",
        kind: "hunk"
      },
      %{id: "diff-2", number: 18, text: "   label = assigns.label", kind: "context"},
      %{id: "diff-3", number: 19, text: "-  render_text(label)", kind: "deletion"},
      %{id: "diff-4", number: 19, text: "+  label", kind: "addition"},
      %{id: "diff-5", number: 20, text: "+  |> render_text()", kind: "addition"},
      %{id: "diff-6", number: 21, text: " end", kind: "context"}
    ]
  end

  defp lines(:long) do
    lines(:code) ++
      [
        %{
          id: "long-line",
          number: 8,
          text:
            "result = " <>
              String.duplicate("pipeline |> normalize() |> validate() |> ", 5) <> "persist()",
          kind: "context"
        }
      ]
  end

  defp viewer_mode(:diff), do: "diff"
  defp viewer_mode(_mode), do: "plain"

  defp subtitle(:diff), do: "Unified diff semantics · added, removed, context, and hunk lines"
  defp subtitle(:long), do: "No wrapping · stable horizontal geometry for long lines"
  defp subtitle(_mode), do: "Monospaced text · line numbers · configurable tab width"
end

defmodule GPUITest.Visual.CodeViewer.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "GPUI Code Viewer Visual" do
         size(720, 480)
         root(GPUITest.Visual.CodeViewer.View, mode: :code, selected: nil)
       end
     ]}
  end
end

defmodule GPUITest.Visual.CodeViewer.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :code_viewer

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GPUITest.Visual.CodeViewer.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "GPUI Code Viewer Visual"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "code"},
      %{name: "diff", actions: [{:send_view, 1, {:mode, :diff}}]},
      %{
        name: "selection",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "line_selected", value: "diff-4"}}
        ]
      },
      %{name: "long-lines", actions: [{:send_view, 1, {:long_line, "long-line"}}]}
    ]
  end
end
