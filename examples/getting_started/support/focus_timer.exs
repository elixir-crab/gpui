defmodule GettingStarted.FocusTimer.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center w-[480px] h-[360px] gap-4 p-8 bg-slate-900">
      <text class="text-white text-xl font-semibold">Focus session</text>
      <text class="text-white text-3xl">{format_time(assigns.remaining)}</text>
      <text class={status_class(assigns.status)}>{status_label(assigns.status)}</text>
      <div class="flex gap-3">
        <UI.button id="start" label={start_label(assigns.status)} variant="primary" phx-click="start" />
        <UI.button id="pause" label="Pause" disabled={assigns.status != :running} phx-click="pause" />
        <UI.button id="reset" label="Reset" phx-click="reset" />
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("start", _event, %{status: :complete} = assigns),
    do: {:noreply, %{assigns | remaining: assigns.duration, status: :running}}

  def handle_event("start", _event, assigns),
    do: {:noreply, %{assigns | status: :running}}

  def handle_event("pause", _event, assigns),
    do: {:noreply, %{assigns | status: :paused}}

  def handle_event("reset", _event, assigns),
    do: {:noreply, %{assigns | remaining: assigns.duration, status: :ready}}

  @impl GPUI.View
  def handle_info(:tick, %{status: :running, remaining: remaining} = assigns)
      when remaining > 1,
      do: {:noreply, %{assigns | remaining: remaining - 1}}

  def handle_info(:tick, %{status: :running} = assigns),
    do: {:noreply, %{assigns | remaining: 0, status: :complete}}

  def handle_info(:tick, assigns), do: {:noreply, assigns}

  defp format_time(seconds) do
    minutes = seconds |> Kernel.div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    seconds = seconds |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes <> ":" <> seconds
  end

  defp start_label(:paused), do: "Resume"
  defp start_label(:complete), do: "Start again"
  defp start_label(_status), do: "Start"

  defp status_label(:ready), do: "Ready when you are"
  defp status_label(:running), do: "Focus mode"
  defp status_label(:paused), do: "Paused"
  defp status_label(:complete), do: "Session complete"

  defp status_class(:complete), do: "text-green-500"
  defp status_class(_status), do: "text-white"
end

defmodule GettingStarted.FocusTimer.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    duration = args |> Map.new() |> Map.get(:seconds, 5 * 60)

    {:ok,
     [
       window "Focus Timer" do
         size(480, 360)

         root(GettingStarted.FocusTimer.View,
           duration: duration,
           remaining: duration,
           status: :ready
         )
       end
     ]}
  end
end

defmodule GettingStarted.FocusTimer.Ticker do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    state = %{
      runtime: Keyword.fetch!(opts, :runtime),
      interval: Keyword.get(opts, :interval, 1_000)
    }

    schedule_tick(state.interval)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:tick, state) do
    {:ok, _snapshot} = GPUI.Runtime.send_view(state.runtime, 1, :tick)
    schedule_tick(state.interval)
    {:noreply, state}
  end

  defp schedule_tick(interval), do: Process.send_after(self(), :tick, interval)
end
