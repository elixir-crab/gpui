defmodule Examples.ComponentGallery.Stories.Checkbox do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "checkbox",
      group: "Components",
      title: "Checkbox",
      description: "A controlled boolean field."
    }

  @impl true
  def initial_state, do: %{checked: true}

  @impl true
  def render_story(state),
    do:
      Components.canvas(
        "Reports",
        UI.checkbox(%{
          id: "gallery-checkbox",
          label: "Email weekly reports",
          checked: state.checked,
          "phx-change": "story:checkbox:changed"
        })
      )

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | checked: value}}
end

defmodule Examples.ComponentGallery.Stories.Switch do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "switch",
      group: "Components",
      title: "Switch",
      description: "Immediate preference state backed by Elixir assigns."
    }

  @impl true
  def initial_state, do: %{checked: true}

  @impl true
  def render_story(state),
    do:
      Components.canvas(
        "Notifications",
        UI.switch(%{
          id: "gallery-switch",
          label: "Desktop notifications",
          checked: state.checked,
          "phx-change": "story:switch:changed"
        })
      )

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | checked: value}}
end

defmodule Examples.ComponentGallery.Stories.Radio do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "radio",
      group: "Components",
      title: "Radio group",
      description: "Exclusive choices with disabled options."
    }

  @impl true
  def initial_state, do: %{value: "team"}

  @impl true
  def render_story(state) do
    options = [
      {"Free", "free"},
      {"Team", "team"},
      %{label: "Enterprise", value: "enterprise", disabled: true}
    ]

    Components.canvas(
      "Plan",
      UI.radio_group(%{
        id: "gallery-plan",
        label: "Plan",
        value: state.value,
        options: options,
        orientation: "horizontal",
        "phx-change": "story:radio:changed"
      })
    )
  end

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | value: value}}
end

defmodule Examples.ComponentGallery.Stories.Slider do
  @behaviour Examples.ComponentGallery.Story
  import GPUI.Template, only: [sigil_GPUI: 2]
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "slider",
      group: "Components",
      title: "Slider",
      description: "A bounded numeric value controlled by the view."
    }

  @impl true
  def initial_state, do: %{value: 65.0}

  @impl true
  def render_story(state) do
    assigns = %{state: state}

    child = ~GPUI"""
    <div class="flex flex-col gap-3"><text>Notification volume: {round(assigns.state.value)}%</text><UI.slider id="gallery-volume" label="Notification volume" value={assigns.state.value} min={0} max={100} step={5} phx-change="story:slider:changed" /></div>
    """

    Components.canvas("Volume", child)
  end

  @impl true
  def story_event("changed", %{value: value}, state), do: {:noreply, %{state | value: value}}
end
