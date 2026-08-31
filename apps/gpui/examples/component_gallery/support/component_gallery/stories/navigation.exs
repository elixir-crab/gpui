defmodule Examples.ComponentGallery.Stories.Tabs do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "tabs",
      group: "Navigation",
      title: "Tabs",
      description: "Roving focus and controlled section selection."
    }

  @impl true
  def initial_state, do: %{value: "overview"}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <div class="flex flex-col gap-5"><UI.tabs id="gallery-tabs" value={assigns.state.value} options={[{"Overview", "overview"}, {"Activity", "activity"}, {"Settings", "settings"}]} variant="underline" phx-change="story:tabs:changed" /><text class="text-slate-600">Selected section: {assigns.state.value}</text></div>
    """

    Components.canvas("Tabs", child)
  end

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | value: value}}
end

defmodule Examples.ComponentGallery.Stories.Accordion do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "accordion",
      group: "Navigation",
      title: "Accordion",
      description: "Multiple controlled disclosure sections."
    }

  @impl true
  def initial_state, do: %{expanded: ["account"]}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <UI.accordion id="gallery-accordion" expanded={assigns.state.expanded} multiple={true} phx-change="story:accordion:changed"><UI.accordion_item id="account" title="Account"><text>Identity, sessions, and connected devices.</text></UI.accordion_item><UI.accordion_item id="billing" title="Billing"><text>Invoices and usage thresholds.</text></UI.accordion_item><UI.accordion_item id="security" title="Security"><text>Passkeys and recovery settings.</text></UI.accordion_item></UI.accordion>
    """

    Components.canvas("Accordion", child)
  end

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | expanded: value}}
end
