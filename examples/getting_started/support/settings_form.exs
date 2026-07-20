defmodule GettingStarted.SettingsForm.View do
  use GPUI.View

  alias GPUI.UI
  alias GPUI.UI.Overlay

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col w-[620px] h-[700px] gap-4 p-6 bg-slate-900">
      <text class="text-white text-2xl font-semibold">Workspace settings</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>A controlled form whose source of truth stays in Elixir.</text>

      <div class="flex flex-col gap-2">
        <text style={[color: {:rgb, 0xCBD5E1}]}>Display name</text>
        <UI.input
          id="display-name"
          value={assigns.name}
          placeholder="Display name"
          cleanable={true}
          phx-change="name_changed"
        />
      </div>

      <div class="flex flex-col gap-2">
        <text style={[color: {:rgb, 0xCBD5E1}]}>Appearance</text>
        <UI.select
          id="preview"
          value={assigns.preview}
          options={[{"Midnight", "midnight"}, {"Paper", "paper"}]}
          phx-change="preview_changed"
        />
      </div>

      <div class="flex flex-col gap-2 p-4 rounded-md" style={preview_style(assigns.preview)}>
        <text style={preview_text_style(assigns.preview)}>Live appearance preview</text>
        <text style={preview_text_style(assigns.preview)}>The native controls remain fully controlled.</text>
      </div>

      <UI.switch
        id="notifications"
        label="Desktop notifications"
        checked={assigns.notifications}
        phx-change="notifications_changed"
      />

      <div class="flex flex-col gap-2">
        <text style={[color: {:rgb, 0xCBD5E1}]}>Interface density</text>
        <UI.radio_group
          id="density"
          label="Density"
          value={assigns.density}
          options={[{"Comfortable", "comfortable"}, {"Compact", "compact"}]}
          orientation="horizontal"
          phx-change="density_changed"
        />
      </div>

      <div class="flex flex-col gap-2">
        <text class="text-white">Notification volume: {round(assigns.volume)}%</text>
        <UI.slider
          id="volume"
          label="Volume"
          value={assigns.volume}
          min={0}
          max={100}
          step={5}
          phx-change="volume_changed"
        />
      </div>

      <div class="flex gap-3">
        <UI.button id="review" label={review_label(assigns.saved)} variant="primary" phx-click="review" />
        <text style={status_style(assigns)}>{status_label(assigns)}</text>
      </div>

      <Overlay.dialog
        id="review-dialog"
        open={assigns.dialog_open}
        title="Review workspace settings"
        width={420}
        phx-change="dialog_changed"
      >
        <:content>
          <div class="flex flex-col gap-3 p-2">
            <text>Name: {display_name(assigns.name)}</text>
            <text>Appearance: {humanize(assigns.preview)}</text>
            <text>Density: {humanize(assigns.density)}</text>
            <text>Notifications: {on_off(assigns.notifications)}</text>
            <text>Notification volume: {round(assigns.volume)}%</text>
            <UI.button id="apply" label="Apply changes" variant="primary" phx-click="apply" />
          </div>
        </:content>
      </Overlay.dialog>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("name_changed", %{value: name}, assigns),
    do: changed(assigns, :name, name)

  def handle_event("preview_changed", %{value: preview}, assigns),
    do: changed(assigns, :preview, preview)

  def handle_event("notifications_changed", %{value: enabled}, assigns),
    do: changed(assigns, :notifications, enabled)

  def handle_event("density_changed", %{value: density}, assigns),
    do: changed(assigns, :density, density)

  def handle_event("volume_changed", %{value: volume}, assigns),
    do: changed(assigns, :volume, volume)

  def handle_event("review", _event, assigns),
    do: {:noreply, %{assigns | dialog_open: true}}

  def handle_event("dialog_changed", %{value: open}, assigns),
    do: {:noreply, %{assigns | dialog_open: open}}

  def handle_event("apply", _event, assigns),
    do: {:noreply, %{assigns | dialog_open: false, saved: true}}

  defp changed(assigns, key, value),
    do: {:noreply, assigns |> Map.put(key, value) |> Map.put(:saved, false)}

  defp preview_style("midnight"), do: [background: {:rgb, 0x1E293B}]
  defp preview_style("paper"), do: [background: {:rgb, 0xF8FAFC}]
  defp preview_text_style("midnight"), do: [color: {:rgb, 0xFFFFFF}]
  defp preview_text_style("paper"), do: [color: {:rgb, 0x111827}]
  defp status_style(%{saved: true}), do: [color: {:rgb, 0x22C55E}]
  defp status_style(_assigns), do: [color: {:rgb, 0x94A3B8}]
  defp status_label(%{saved: true}), do: "Settings up to date"
  defp status_label(_assigns), do: "Unsaved changes"
  defp review_label(true), do: "Review settings"
  defp review_label(false), do: "Review changes"
  defp display_name(""), do: "Anonymous"
  defp display_name(name), do: name
  defp on_off(true), do: "On"
  defp on_off(false), do: "Off"
  defp humanize(value), do: value |> String.replace("_", " ") |> String.capitalize()
end

defmodule GettingStarted.SettingsForm.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Workspace Settings" do
         size(620, 700)

         root(GettingStarted.SettingsForm.View,
           name: "Ada Lovelace",
           preview: "midnight",
           notifications: true,
           density: "comfortable",
           volume: 65.0,
           dialog_open: false,
           saved: true
         )
       end
     ]}
  end
end
