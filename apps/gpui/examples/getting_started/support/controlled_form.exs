defmodule GettingStarted.ControlledForm.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex grow items-start justify-center p-8">
      <div class="flex flex-col w-[460px] gap-4">
        <text class="text-xl font-semibold">Profile</text>

        <UI.field label="Display name" required={true} error={assigns.error}>
          <UI.input id="display-name" label="Display name" value={assigns.name} placeholder="Ada Lovelace" phx-change="name_changed" phx-submit="save" />
        </UI.field>

        <UI.switch id="notifications" label="Desktop notifications" checked={assigns.notifications} phx-change="notifications_changed" />
        <UI.button id="save" label="Save" variant="primary" phx-click="save" />
        <text class="text-sm text-slate-500">{assigns.status}</text>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("name_changed", %{value: name}, assigns), do: {:noreply, %{assigns | name: name, status: "Unsaved", error: nil}}
  def handle_event("notifications_changed", %{value: value}, assigns), do: {:noreply, %{assigns | notifications: value, status: "Unsaved"}}
  def handle_event("save", %{value: name}, assigns), do: save(%{assigns | name: name})
  def handle_event("save", _event, assigns), do: save(assigns)

  defp save(assigns) do
    if String.trim(assigns.name) == "" do
      {:noreply, %{assigns | error: "Enter a display name.", status: "Not saved"}}
    else
      {:noreply, %{assigns | error: nil, status: "Saved"}}
    end
  end
end

defmodule GettingStarted.ControlledForm.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Controlled Form" do
         size(560, 420)
         root(GettingStarted.ControlledForm.View, name: "Ada Lovelace", notifications: true, error: nil, status: "Saved")
       end
     ]}
  end
end
