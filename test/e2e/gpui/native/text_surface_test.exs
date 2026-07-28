defmodule GPUI.Native.TextSurfaceE2ETest do
  use ExUnit.Case, async: false

  alias GPUI.Text.{Buffer, Edit, Position, Range, Selection, Transaction}
  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule SharedSurfaceView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[640px] h-[420px] p-4 gap-3 bg-slate-900">
        <text_surface
          id="primary-surface"
          class="w-full h-[150px] p-2 bg-slate-800 text-white"
          buffer={assigns.buffer}
          focus_request={assigns.primary_focus}
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
        <text_surface
          id="mirror-surface"
          class="w-full h-[150px] p-2 bg-slate-950 text-white"
          buffer={assigns.buffer}
          focus_request={assigns.mirror_focus}
          phx-transaction="text-transaction"
          phx-selection-change="selection-changed"
        />
        <text class="text-white">Revision: {assigns.revision}; Transactions: {assigns.transactions}; Selections: {assigns.selections}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("text-transaction", %{revision: revision}, assigns),
      do: {:noreply, %{assigns | revision: revision, transactions: assigns.transactions + 1}}

    def handle_event("selection-changed", %{revision: revision}, assigns),
      do: {:noreply, %{assigns | revision: revision, selections: assigns.selections + 1}}

    def handle_event("viewport-changed", %{revision: revision, value: viewport}, assigns) do
      true = viewport.first_visible_row <= viewport.last_visible_row
      {:noreply, %{assigns | revision: revision, viewports: assigns.viewports + 1}}
    end

    def handle_event("geometry-changed", %{revision: revision, value: geometry}, assigns) do
      true = geometry.line >= 0 and geometry.utf16_offset >= 0
      {:noreply, %{assigns | revision: revision, geometries: assigns.geometries + 1}}
    end

    def handle_event("range-geometry-changed", %{revision: revision, value: ranges}, assigns) do
      true = Enum.count_until(ranges, 65) <= 64
      {:noreply, %{assigns | revision: revision, range_geometries: length(ranges)}}
    end

    def handle_event("hit-tested", %{revision: revision, value: position}, assigns) do
      true = position.line >= 0 and position.utf16_offset >= 0
      {:noreply, %{assigns | revision: revision, hit_tests: assigns.hit_tests + 1}}
    end
  end

  defmodule SharedSurfaceApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title, buffer: buffer}) do
      {:ok,
       [
         window title do
           size(640, 420)

           root(SharedSurfaceView,
             buffer: buffer,
             geometry_ranges: [Range.new(Position.new(0, 0), Position.new(0, 3))],
             scroll_request: 0,
             scroll_to: Position.new(0, 0),
             revision: 0,
             transactions: 0,
             selections: 0,
             viewports: 0,
             geometries: 0,
             range_geometries: 0,
             hit_tests: 0,
             primary_focus: 1,
             mirror_focus: 0
           )
         end
       ]}
    end
  end

  test "shared surfaces reconcile native typing and external edit undo redo" do
    {:ok, buffer} = Buffer.new("alpha")
    title = "GPUI Text Surface E2E #{System.unique_integer([:positive])}"

    {:ok, runtime} =
      GPUI.Runtime.start_link(app: SharedSurfaceApp, args: %{title: title, buffer: buffer})

    :ok = GPUI.Runtime.subscribe(runtime)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)

    Desktop.eventually(fn ->
      assert %{viewports: viewports, geometries: geometries, range_geometries: ranges} =
               assigns(runtime)

      assert viewports > 0
      assert geometries > 0
      assert ranges == 1
    end)

    Desktop.click!(window_id, 120, 70)

    Desktop.eventually(fn ->
      assert %{hit_tests: hit_tests} = assigns(runtime)
      assert hit_tests > 0
    end)

    Desktop.key!(window_id, "End")
    Desktop.type!(window_id, "-native")

    Desktop.eventually(fn ->
      assert {:ok, %{text: "alpha-native", revision: revision}} = Buffer.snapshot(buffer)
      assert revision > 0
      assert %{transactions: transactions} = assigns(runtime)
      assert transactions > 0
    end)

    {:ok, snapshot} = Buffer.snapshot(buffer)
    external_position = Position.new(0, 0)
    selection = Selection.caret("primary", external_position, primary: true)

    assert {:ok, %{revision: external_revision}} =
             Buffer.transact(buffer, %Transaction{
               id: "external-e2e",
               base_revision: snapshot.revision,
               edits: [Edit.new(Range.new(external_position, external_position), "external-")],
               selections: [selection]
             })

    assert {:ok, _snapshot} = GPUI.Runtime.refresh(runtime)
    Desktop.request_frame!(window_id)

    Desktop.eventually(fn ->
      assert {:ok, %{text: "external-alpha-native"}} = Buffer.snapshot(buffer)
      assert %{transactions: transactions} = assigns(runtime)
      assert transactions > 0
    end)

    assert {:ok, %{revision: undo_revision, text: "alpha-native"}} =
             Buffer.undo(buffer, external_revision)

    assert {:ok, _snapshot} = GPUI.Runtime.refresh(runtime)
    Desktop.request_frame!(window_id)

    assert {:ok, %{revision: redo_revision, text: "external-alpha-native"}} =
             Buffer.redo(buffer, undo_revision)

    assert {:ok, _snapshot} = GPUI.Runtime.refresh(runtime)
    Desktop.request_frame!(window_id)

    Desktop.click!(window_id, 120, 245)
    Desktop.key!(window_id, "End")
    Desktop.type!(window_id, "-mirror")

    Desktop.eventually(fn ->
      assert {:ok, %{text: "external-alpha-native-mirror", revision: revision}} =
               Buffer.snapshot(buffer)

      assert revision > redo_revision
      assert %{transactions: transactions} = assigns(runtime)
      assert transactions > 1
    end)

    Desktop.close_window!(window_id)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
