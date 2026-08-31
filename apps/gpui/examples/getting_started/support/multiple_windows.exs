defmodule GettingStarted.MultipleWindows.DetailsView do
  use GPUI.View

  @impl GPUI.View
  def render(_assigns) do
    ~GPUI"""
    <div class="flex grow items-center justify-center p-8">
      <text class="text-lg">This window has its own view state.</text>
    </div>
    """
  end
end

defmodule GettingStarted.MultipleWindows.MainView do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex grow flex-col items-center justify-center gap-4 p-8">
      <text class="text-xl font-semibold">Window topology belongs to the application</text>
      <UI.button id="toggle-details" label={if(assigns.open, do: "Close details", else: "Open details")} variant="primary" phx-click="toggle_details" />
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("toggle_details", _event, %{open: false} = assigns) do
    details = %GPUI.WindowSpec{
      key: "details",
      title: "Details",
      size: {420, 240},
      root: {GettingStarted.MultipleWindows.DetailsView, %{}}
    }

    {:open_window, details, %{assigns | open: true}}
  end

  def handle_event("toggle_details", _event, %{open: true} = assigns),
    do: {:close_window, "details", %{assigns | open: false}}
end

defmodule GettingStarted.MultipleWindows.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "main", "Multiple Windows" do
         size(620, 320)
         root(GettingStarted.MultipleWindows.MainView, open: false)
       end
     ]}
  end
end
