defmodule Examples.ComponentGallery.Stories.Welcome do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]

  @impl true
  def metadata,
    do: %{
      id: "welcome",
      group: "Getting started",
      title: "Introduction",
      description: "Native components with state and events owned by an Elixir view process."
    }

  @impl true
  def initial_state, do: %{}

  @impl true
  def render_story(_state) do
    ~GPUI"""
    <div class="flex grow items-start">
      <div class="flex flex-col w-[640px] gap-5 pt-8">
        <text class="text-2xl font-semibold text-slate-900">Build native interfaces with ordinary Elixir</text>
        <text class="text-base text-slate-600">Select a component to inspect its states and behavior. Values remain in the view process; the native host handles focus, input, layout, and paint.</text>
        <div class="flex gap-3 border-t border-slate-200 pt-5">
          <text class="text-sm text-slate-500">GPUI.Application</text><text class="text-sm text-slate-400">→</text>
          <text class="text-sm text-slate-500">GPUI.View</text><text class="text-sm text-slate-400">→</text>
          <text class="text-sm text-slate-500">GPUI Snapshot</text>
        </div>
      </div>
    </div>
    """
  end
end
