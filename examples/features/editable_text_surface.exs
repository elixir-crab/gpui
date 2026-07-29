defmodule Features.EditableTextSurface.View do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex grow flex-col w-full h-full bg-slate-900 text-white">
      <div class="flex items-center justify-between px-4 py-2 bg-slate-800 border-b border-slate-700">
        <text class="font-semibold">Editable text primitives</text>
        <text class="text-xs text-slate-400">revision {assigns.revision}</text>
      </div>
      <div class="flex grow min-h-0">
        <div
          class="flex w-12 flex-col items-end pr-3 bg-slate-950 text-slate-500"
          style={[padding_top: {:px, assigns.gutter_offset}]}
        >
          {gutter(assigns.visible_rows, assigns.line_height)}
        </div>
        <text_surface
          id="document"
          class="grow min-w-0 p-3 bg-slate-900 text-sm"
          buffer={assigns.buffer}
          focus_request={assigns.focus_request}
          tab_size={2}
          geometry_ranges={assigns.geometry_ranges}
          scroll_request={assigns.scroll_request}
          scroll_to={assigns.scroll_to}
          phx-transaction="text-transaction"
          phx-selection-change="selection-changed"
          phx-viewport-change="viewport-changed"
          phx-geometry-change="geometry-changed"
          phx-range-geometry-change="range-geometry-changed"
          phx-hit-test="hit-tested"
        />
      </div>
      <div class="flex items-center justify-between px-4 py-2 bg-slate-800 border-t border-slate-700">
        <div class="flex items-center gap-3">
          <text class="text-xs text-slate-400">{assigns.visible}</text>
          <text class="text-xs text-slate-400">{assigns.caret}</text>
          <text class="text-xs text-slate-400">{assigns.ranges}</text>
          <text class="text-xs text-slate-400">{assigns.hit}</text>
          <text class="text-xs text-slate-400">{assigns.status}</text>
        </div>
        <div class="flex items-center gap-2">
          <button phx-click="external-edit" class="px-3 py-1 bg-slate-700 rounded">External edit</button>
          <button phx-click="undo" class="px-3 py-1 bg-slate-700 rounded">Undo</button>
          <button phx-click="redo" class="px-3 py-1 bg-slate-700 rounded">Redo</button>
          <button phx-click="scroll-start" class="px-3 py-1 bg-slate-700 rounded">Scroll start</button>
          <button phx-click="focus-editor" class="px-3 py-1 bg-blue-600 rounded">Focus</button>
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("text-transaction", %{revision: revision}, assigns),
    do: {:noreply, %{assigns | revision: revision, status: "Native transaction applied"}}

  def handle_event("selection-changed", %{value: selections, revision: revision}, assigns),
    do: {:noreply, %{assigns | revision: revision, status: "#{length(selections)} selection(s)"}}

  def handle_event("viewport-changed", %{value: viewport}, assigns) do
    viewport = GPUI.Text.Viewport.from_event(viewport)
    visible_rows = Enum.to_list(viewport.first_visible_row..viewport.last_visible_row)
    visible = "rows #{viewport.first_visible_row + 1}–#{viewport.last_visible_row + 1}"
    gutter_offset = 12.0 + remainder(viewport.scroll_y, viewport.line_height)

    {:noreply,
     %{
       assigns
       | visible: visible,
         visible_rows: visible_rows,
         line_height: viewport.line_height,
         gutter_offset: gutter_offset
     }}
  end

  def handle_event("geometry-changed", %{value: caret}, assigns) do
    caret = GPUI.Text.CaretGeometry.from_event(caret)
    label = "Ln #{caret.line + 1}, Col #{caret.utf16_offset + 1}"
    {:noreply, %{assigns | caret: label}}
  end

  def handle_event("range-geometry-changed", %{value: ranges}, assigns) do
    ranges = Enum.map(ranges, &GPUI.Text.RangeGeometry.from_event/1)
    rectangle_count = Enum.sum(Enum.map(ranges, &length(&1.rectangles)))
    {:noreply, %{assigns | ranges: "#{rectangle_count} visual rectangle(s)"}}
  end

  def handle_event("hit-tested", %{value: position}, assigns) do
    hit = "Hit Ln #{position.line + 1}, Col #{position.utf16_offset + 1}"
    {:noreply, %{assigns | hit: hit}}
  end

  def handle_event("focus-editor", _event, assigns),
    do: {:noreply, %{assigns | focus_request: assigns.focus_request + 1}}

  def handle_event("scroll-start", _event, assigns),
    do: {:noreply, %{assigns | scroll_request: assigns.scroll_request + 1}}

  def handle_event("external-edit", _event, assigns) do
    {:ok, snapshot} = GPUI.Text.Buffer.snapshot(assigns.buffer)
    position = end_position(snapshot.text)

    {:ok, %{revision: revision}} =
      GPUI.Text.Buffer.transact(assigns.buffer, %GPUI.Text.Transaction{
        id: "demo-external-#{System.unique_integer([:positive])}",
        base_revision: snapshot.revision,
        edits: [GPUI.Text.Edit.new(GPUI.Text.Range.new(position, position), "\nExternal edit")],
        selections: [GPUI.Text.Selection.caret("primary", position, primary: true)]
      })

    {:noreply, %{assigns | revision: revision, status: "External edit applied"}}
  end

  def handle_event("undo", _event, assigns) do
    {:ok, snapshot} = GPUI.Text.Buffer.snapshot(assigns.buffer)

    case GPUI.Text.Buffer.undo(assigns.buffer, snapshot.revision) do
      {:ok, updated} ->
        {:noreply, %{assigns | revision: updated.revision, status: "Undo applied"}}

      {:error, :nothing_to_undo} ->
        {:noreply, %{assigns | status: "Nothing to undo"}}
    end
  end

  def handle_event("redo", _event, assigns) do
    {:ok, snapshot} = GPUI.Text.Buffer.snapshot(assigns.buffer)

    case GPUI.Text.Buffer.redo(assigns.buffer, snapshot.revision) do
      {:ok, updated} ->
        {:noreply, %{assigns | revision: updated.revision, status: "Redo applied"}}

      {:error, :nothing_to_redo} ->
        {:noreply, %{assigns | status: "Nothing to redo"}}
    end
  end

  defp gutter(rows, line_height) do
    Enum.map(rows, fn row ->
      %GPUI.Element{
        type: :text,
        attrs: [class: "text-sm", style: [height: {:px, line_height}]],
        children: [Integer.to_string(row + 1)]
      }
    end)
  end

  defp remainder(_scroll_y, line_height) when line_height <= 0, do: 0.0

  defp remainder(scroll_y, line_height),
    do: scroll_y - Float.floor(scroll_y / line_height) * line_height

  defp end_position(text) do
    lines = String.split(text, "\n", trim: false)
    line = length(lines) - 1
    content = List.last(lines)
    GPUI.Text.Position.new(line, content |> :unicode.characters_to_binary() |> utf16_length())
  end

  defp utf16_length(text) do
    utf16 = :unicode.characters_to_binary(text, :utf8, {:utf16, :little})
    Kernel.div(byte_size(utf16), 2)
  end
end

defmodule Features.EditableTextSurface.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok, buffer} =
      GPUI.Text.Buffer.new(
        "# Neutral editable text\n\nThis surface owns no file, language, gutter, or IDE policy.\nEdit me with native keyboard and IME input.\n"
      )

    requested_range =
      GPUI.Text.Range.new(GPUI.Text.Position.new(0, 0), GPUI.Text.Position.new(0, 7))

    assigns = %{
      buffer: buffer,
      geometry_ranges: [requested_range],
      scroll_request: 0,
      scroll_to: GPUI.Text.Position.new(0, 0),
      revision: 0,
      focus_request: 1,
      visible: "viewport pending",
      visible_rows: [],
      line_height: 20.0,
      gutter_offset: 12.0,
      caret: "geometry pending",
      ranges: "range geometry pending",
      hit: "hit test pending",
      status: "Ready"
    }

    {:ok,
     [
       window "Editable Text Surface" do
         size(760, 480)
         root(Features.EditableTextSurface.View, assigns)
       end
     ]}
  end
end
