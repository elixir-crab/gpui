defmodule GettingStarted.Events.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex grow flex-col items-center justify-center gap-4 p-8">
      <text class="text-sm text-slate-500">Application-owned count</text>
      <text class="text-3xl font-semibold">{assigns.count}</text>
      <div class="flex gap-2">
        <UI.button id="decrement" label="−" phx-click="decrement" />
        <UI.button id="increment" label="+" variant="primary" phx-click="increment" />
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("increment", _event, assigns), do: {:noreply, %{assigns | count: assigns.count + 1}}
  def handle_event("decrement", _event, assigns), do: {:noreply, %{assigns | count: assigns.count - 1}}
end

defmodule GettingStarted.Events.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Events" do
         size(420, 280)
         root(GettingStarted.Events.View, count: 0)
       end
     ]}
  end
end
