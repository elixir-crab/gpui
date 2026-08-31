defmodule Examples.ComponentGallery.Stories.Button do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "button",
      group: "Components",
      title: "Button",
      description: "Action hierarchy, disabled state, and loading feedback."
    }

  @impl true
  def initial_state, do: %{}

  @impl true
  def render_story(_state) do
    child = ~GPUI"""
    <div class="flex flex-wrap items-center gap-3">
      <UI.button id="button-default" label="Default" />
      <UI.button id="button-primary" label="Primary" variant="primary" />
      <UI.button id="button-danger" label="Delete" variant="danger" />
      <UI.button id="button-loading" label="Saving" loading={true} />
      <UI.button id="button-disabled" label="Disabled" disabled={true} />
    </div>
    """

    Components.canvas("Button variants", child)
  end
end

defmodule Examples.ComponentGallery.Stories.Progress do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "progress",
      group: "Components",
      title: "Progress",
      description: "Bounded progress with an accessible label."
    }

  @impl true
  def initial_state, do: %{}

  @impl true
  def render_story(_state) do
    child = ~GPUI"""
    <div class="flex flex-col gap-3"><div class="flex justify-between"><text>Release archive</text><text class="text-slate-500">72%</text></div><UI.progress id="gallery-progress" label="Deployment progress" value={72} max={100} /></div>
    """

    Components.canvas("Deployment", child)
  end
end
