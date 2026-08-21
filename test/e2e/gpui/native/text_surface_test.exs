defmodule GPUI.Native.TextSurfaceE2ETest do
  use GPUI.Test, desktop: true

  alias GPUI.Text.{Buffer, Position, Range}

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule SharedSurfaceView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div
        id="root-bounds"
        phx-bounds-change="bounds-changed"
        class="flex flex-col w-[640px] h-[420px] p-4 gap-3 bg-slate-900"
      >
        <text_surface
          id="primary-surface"
          class="w-full h-[150px] p-2 bg-slate-800 text-white"
          buffer={assigns.buffer}
          focus_request={assigns.primary_focus}
          geometry_ranges={assigns.geometry_ranges}
          decorations={assigns.decorations}
          style_runs={assigns.style_runs}
          inline_projections={assigns.inline_projections}
          block_projections={assigns.block_projections}
          scroll_request={assigns.scroll_request}
          scroll_to={assigns.scroll_to}
          phx-transaction="text-transaction"
          phx-selection-change="selection-changed"
          phx-viewport-change="viewport-changed"
          phx-geometry-change="geometry-changed"
          phx-range-geometry-change="range-geometry-changed"
          phx-hit-test="hit-tested"
          phx-focus="surface-focused"
          phx-blur="surface-blurred"
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
    def handle_event("bounds-changed", %{value: bounds}, assigns) do
      true = bounds.id == "root-bounds"
      true = bounds.coordinate_space == "window_native_pixels"
      true = bounds.width > 0 and bounds.height > 0
      {:noreply, %{assigns | bounds: assigns.bounds + 1}}
    end

    def handle_event("surface-focused", %{value: %{id: "primary-surface"}}, assigns),
      do: {:noreply, %{assigns | focuses: assigns.focuses + 1}}

    def handle_event("surface-blurred", %{value: %{id: "primary-surface"}}, assigns),
      do: {:noreply, %{assigns | blurs: assigns.blurs + 1}}

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
      rectangles = Enum.sum(Enum.map(ranges, &length(&1.rectangles)))
      {:noreply, %{assigns | revision: revision, range_geometries: rectangles}}
    end

    def handle_event("hit-tested", %{revision: revision, value: position}, assigns) do
      true = position.line >= 0 and position.utf16_offset >= 0
      {:noreply, %{assigns | revision: revision, hit_tests: assigns.hit_tests + 1}}
    end

    @impl GPUI.View
    def handle_window_event(:close_request, _event, assigns),
      do: {:noreply, %{assigns | close_requests: assigns.close_requests + 1}}

    def handle_window_event(:focus, _event, assigns),
      do: {:noreply, %{assigns | window_focuses: assigns.window_focuses + 1}}

    def handle_window_event(:blur, _event, assigns),
      do: {:noreply, %{assigns | window_blurs: assigns.window_blurs + 1}}
  end

  defmodule SharedSurfaceApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title, buffer: buffer}) do
      {:ok,
       [
         window title do
           size(640, 420)
           min_size(480, 320)

           root(SharedSurfaceView,
             buffer: buffer,
             geometry_ranges: [Range.new(Position.new(0, 0), Position.new(0, 3))],
             decorations: [
               GPUI.Text.Decoration.new(Range.new(Position.new(0, 0), Position.new(0, 3)),
                 background: 0x263D66,
                 underline: 0x60A5FA,
                 underline_style: :wavy
               )
             ],
             style_runs: [
               GPUI.Text.StyleRun.new(Range.new(Position.new(0, 0), Position.new(0, 5)),
                 color: 0xF97316,
                 font_weight: :semibold
               )
             ],
             inline_projections: [
               GPUI.Text.InlineProjection.new(Position.new(0, 3), " ghost")
             ],
             block_projections: [
               GPUI.Text.BlockProjection.new(0, "note", background: 0x1E293B)
             ],
             scroll_request: 0,
             scroll_to: Position.new(0, 0),
             revision: 0,
             transactions: 0,
             selections: 0,
             viewports: 0,
             geometries: 0,
             range_geometries: 0,
             hit_tests: 0,
             bounds: 0,
             focuses: 0,
             blurs: 0,
             close_requests: 0,
             window_focuses: 0,
             window_blurs: 0,
             primary_focus: 1,
             mirror_focus: 0
           )
         end
       ]}
    end
  end

  test "desktop renders shared persistent text surfaces", %{desktop: desktop} do
    {:ok, buffer} = Buffer.new("alpha")
    title = "GPUI Text Surface E2E #{System.unique_integer([:positive])}"

    runtime =
      start_runtime!(desktop, app: SharedSurfaceApp, args: %{title: title, buffer: buffer})

    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert {:ok, %{text: "alpha"}} = Buffer.snapshot(buffer)
    assert Process.alive?(runtime)
  end
end
