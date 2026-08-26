defmodule Features.PresentationPrimitives.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(_assigns) do
    ~GPUI"""
    <div class="flex flex-col w-full h-full gap-4 p-6 bg-slate-950 text-white">
      <UI.frost
        id="summary-frost"
        fallback="translucent"
        opacity={0.86}
        reduced_transparency={false}
        class="p-4 rounded-lg border border-slate-700"
      >
        <text class="font-semibold">Schema-owned frost with an explicit fallback</text>
      </UI.frost>

      <UI.edge_fade
        id="activity-fades"
        edges={[:top, :bottom]}
        size={24}
        class="relative grow min-h-0 rounded-lg bg-slate-900"
      >
        <scroll class="w-full h-full p-5">
          <text>Edge fades decorate arbitrary child content without owning scrolling.</text>
        </scroll>
      </UI.edge_fade>

      <UI.paint
        id="sparkline"
        commands={[
          %{type: :rect, x: 0, y: 30, width: 220, height: 1, color: 0x334155FF},
          %{type: :line, x1: 8, y1: 28, x2: 210, y2: 6, width: 2, color: 0x38BDF8FF}
        ]}
        class="w-full h-12"
      />
    </div>
    """
  end
end

defmodule Features.PresentationPrimitives.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Presentation primitives" do
         size(640, 420)
         root(Features.PresentationPrimitives.View, %{})
       end
     ]}
  end
end
