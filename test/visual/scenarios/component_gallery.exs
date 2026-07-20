defmodule GPUITest.Visual.ComponentGallery.View do
  use GPUI.View

  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col w-[640px] h-[860px] gap-4 p-4" style={background_style(assigns.theme)}>
      <text class="text-2xl font-semibold" style={foreground_style(assigns.theme)}>GPUI component gallery</text>
      <UI.button id="primary" label="Primary button" variant="primary" />
      <UI.checkbox id="checked" label="Checked checkbox" checked={true} phx-change="noop" />
      <UI.switch id="notifications" label="Notifications" checked={true} phx-change="noop" />
      <UI.input id="name" value="Ada Lovelace" placeholder="Name" cleanable={true} phx-change="noop" />
      <UI.select id="language" value="elixir" options={[{"Elixir", "elixir"}, {"Rust", "rust"}]} phx-change="noop" />
      <UI.combobox id="framework" value="Phoenix" options={["Phoenix", "LiveView"]} phx-change="noop" />
      <UI.radio_group
        id="plan"
        value="team"
        options={[{"Free", "free"}, {"Team", "team"}, %{label: "Pro", value: "pro", disabled: true}]}
        orientation="horizontal"
        phx-change="noop"
      />
      <UI.tabs
        id="section"
        value="general"
        options={[{"General", "general"}, {"Advanced", "advanced"}]}
        variant="underline"
        phx-change="noop"
      />
      <UI.slider id="volume" value={65} min={0} max={100} phx-change="noop" />
      <UI.accordion id="details" expanded={["account"]} phx-change="noop">
        <UI.accordion_item id="account" title="Account">
          <text>Account details</text>
        </UI.accordion_item>
        <UI.accordion_item id="security" title="Security">
          <text>Security details</text>
        </UI.accordion_item>
      </UI.accordion>
      <Overlay.popover id="gallery-popover" open={assigns.overlay == "popover"}>
        <:trigger><UI.button id="popover-trigger" label="Popover" /></:trigger>
        <:content><text>Popover content</text></:content>
      </Overlay.popover>
      <Overlay.tooltip id="gallery-tooltip" delay={100}>
        <:trigger><UI.button id="tooltip-trigger" label="Tooltip" /></:trigger>
        <:content>Tooltip content</:content>
      </Overlay.tooltip>
      <Overlay.dialog
        id="gallery-dialog"
        open={assigns.overlay == "dialog"}
        title="Visual review dialog"
        width={360}
      >
        <:content><UI.input id="dialog-input" value="Dialog content" phx-change="noop" /></:content>
      </Overlay.dialog>
      <Overlay.dropdown_menu id="gallery-menu" open={assigns.overlay == "menu"}>
        <:trigger><UI.button id="menu-trigger" label="File menu" /></:trigger>
        <:item value="new">New file</:item>
        <:item value="recent" checked={true}>Open recent</:item>
        <:item value="delete" disabled={true}>Delete</:item>
      </Overlay.dropdown_menu>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("show_overlay", %{value: overlay}, assigns),
    do: {:noreply, %{assigns | overlay: overlay}}

  def handle_event("noop", _event, assigns), do: {:noreply, assigns}

  defp background_style(:dark), do: [background: {:rgb, 0x0F172A}]
  defp background_style(:light), do: [background: {:rgb, 0xFFFFFF}]
  defp foreground_style(:dark), do: [color: {:rgb, 0xFFFFFF}]
  defp foreground_style(:light), do: [color: {:rgb, 0x000000}]
end

defmodule GPUITest.Visual.ComponentGallery.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(%{theme: theme}) do
    {:ok,
     [
       window "GPUI Visual Gallery" do
         size(640, 860)
         root(GPUITest.Visual.ComponentGallery.View, overlay: nil, theme: theme)
       end
     ]}
  end
end

defmodule GPUITest.Visual.ComponentGallery.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :component_gallery

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GPUITest.Visual.ComponentGallery.App

  @impl GPUI.Dev.Visual.Scenario
  def args(theme), do: %{theme: theme}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "GPUI Visual Gallery"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "components"},
      %{name: "popover", actions: [dispatch("popover")]},
      %{
        name: "tooltip",
        actions: [dispatch(nil), {:hover, 320, 666, 2}],
        after: [{:move_mouse, 1, 1}]
      },
      %{name: "dialog", actions: [dispatch("dialog")]},
      %{name: "dropdown-menu", actions: [dispatch("menu")]}
    ]
  end

  defp dispatch(overlay) do
    {:dispatch, %{type: :change, window_id: 1, event: "show_overlay", value: overlay}}
  end
end
