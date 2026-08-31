defmodule Examples.ComponentGallery.Stories.Popover do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl true
  def metadata,
    do: %{
      id: "popover",
      group: "Overlays",
      title: "Popover",
      description: "Controlled lightweight content anchored to a trigger."
    }

  @impl true
  def initial_state, do: %{open: false}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <Overlay.popover id="gallery-popover" label="Runtime process" open={assigns.state.open} phx-change="story:popover:changed"><:trigger><UI.button id="show-popover" label="Inspect process" phx-click="story:popover:open" /></:trigger><:content><div class="flex flex-col gap-1 p-2"><text class="font-semibold">Examples.ComponentGallery.View</text><text class="text-slate-500">Authoritative state: Elixir process</text></div></:content></Overlay.popover>
    """

    Components.canvas("Popover", child)
  end

  @impl true
  def story_event("open", _payload, state), do: {:noreply, %{state | open: true}}

  @impl true
  def story_event("changed", %{value: value}, state),
    do: {:noreply, %{state | open: value == "popover" or value == true}}
end

defmodule Examples.ComponentGallery.Stories.Tooltip do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl true
  def metadata,
    do: %{
      id: "tooltip",
      group: "Overlays",
      title: "Tooltip",
      description: "Delayed contextual help without application state."
    }

  @impl true
  def initial_state, do: %{}

  @impl true
  def render_story(_state) do
    child = ~GPUI"""
    <Overlay.tooltip id="gallery-tooltip" delay={100}><:trigger><UI.button id="tooltip-trigger" label="Hover for details" /></:trigger><:content>Rendered by the native GPUI host</:content></Overlay.tooltip>
    """

    Components.canvas("Tooltip", child)
  end
end

defmodule Examples.ComponentGallery.Stories.Dialog do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl true
  def metadata,
    do: %{
      id: "dialog",
      group: "Overlays",
      title: "Dialog",
      description: "Controlled modal presentation and focus management."
    }

  @impl true
  def initial_state, do: %{open: false}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <div><UI.button id="show-dialog" label="Open dialog" variant="primary" phx-click="story:dialog:open" /><Overlay.dialog id="gallery-dialog" open={assigns.state.open} title="Create workspace" width={420} phx-change="story:dialog:changed"><:content><div class="flex flex-col gap-3 p-2"><UI.input id="dialog-name" label="Workspace name" value="Observatory" phx-change="story:dialog:noop" /><UI.button id="dialog-create" label="Create workspace" variant="primary" /></div></:content></Overlay.dialog></div>
    """

    Components.canvas("Dialog", child)
  end

  @impl true
  def story_event("open", _payload, state), do: {:noreply, %{state | open: true}}

  @impl true
  def story_event("changed", %{value: value}, state),
    do: {:noreply, %{state | open: value == "dialog" or value == true}}

  @impl true
  def story_event("noop", _payload, state), do: {:noreply, state}
end

defmodule Examples.ComponentGallery.Stories.DropdownMenu do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl true
  def metadata,
    do: %{
      id: "menu",
      group: "Overlays",
      title: "Dropdown menu",
      description: "A bounded set of commands and checked states."
    }

  @impl true
  def initial_state, do: %{open: false, result: nil}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <div class="flex items-center gap-4"><Overlay.dropdown_menu id="gallery-menu" label="Workspace actions" open={assigns.state.open} phx-change="story:menu:changed" phx-select="story:menu:selected"><:trigger><UI.button id="show-menu" label="Actions" phx-click="story:menu:open" /></:trigger><:item value="duplicate">Duplicate</:item><:item value="pin" checked={true}>Pinned</:item><:item value="archive">Archive</:item><:item value="delete" disabled={true}>Delete permanently</:item></Overlay.dropdown_menu><text class="text-sm text-slate-500">{assigns.state.result || "No command selected"}</text></div>
    """

    Components.canvas("Dropdown menu", child)
  end

  @impl true
  def story_event("open", _payload, state), do: {:noreply, %{state | open: true}}

  @impl true
  def story_event("changed", %{value: value}, state),
    do: {:noreply, %{state | open: value == "menu" or value == true}}

  @impl true
  def story_event("selected", %{value: value}, state),
    do: {:noreply, %{state | open: false, result: value}}
end
