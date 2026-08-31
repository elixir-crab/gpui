defmodule Examples.ComponentGallery.Stories.Input do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "input",
      group: "Components",
      title: "Input",
      description: "Controlled text input and cleanable state."
    }

  @impl true
  def initial_state, do: %{name: "Ada Lovelace"}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <UI.input id="gallery-name" label="Display name" value={assigns.state.name} cleanable={true} phx-change="story:input:changed" />
    """

    Components.canvas("Profile", child)
  end

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | name: value}}
end

defmodule Examples.ComponentGallery.Stories.Select do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "select",
      group: "Components",
      title: "Select & combobox",
      description: "Fixed and searchable application-owned choices."
    }

  @impl true
  def initial_state, do: %{language: "elixir", framework: "Phoenix"}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <div class="flex flex-col gap-4"><UI.select id="gallery-language" label="Language" value={assigns.state.language} options={[{"Elixir", "elixir"}, {"Rust", "rust"}]} phx-change="story:select:language" /><UI.combobox id="gallery-framework" label="Framework" value={assigns.state.framework} options={["Phoenix", "LiveView", "Ash"]} phx-change="story:select:framework" /></div>
    """

    Components.canvas("Runtime", child)
  end

  @impl true
  def story_event("language", %{value: value}, state), do: {:noreply, %{state | language: value}}

  @impl true
  def story_event("framework", %{value: value}, state),
    do: {:noreply, %{state | framework: value}}
end
