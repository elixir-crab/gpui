# Run with:
#   PATH="$HOME/.cargo/bin:$PATH" mix gpui.native.build --real-gpui
#   PATH="$HOME/.cargo/bin:$PATH" mix run examples/counter.exs

defmodule CounterView do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center bg-slate-900 text-white text-2xl">
      <text>Count: {assigns.count}</text>
      <button phx-click="inc" class="bg-blue-600 text-white text-xl">
        +
      </button>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("inc", _event, assigns) do
    {:noreply, %{assigns | count: assigns.count + 1}}
  end
end

defmodule CounterApp do
  alias GPUI.WindowSpec

  def mount(_args) do
    {:ok, %{}, [%WindowSpec{title: "GPUI Counter", root: {CounterView, %{count: 0}}}]}
  end
end

{:ok, pid} = GPUI.Runtime.start_link(app: CounterApp, backend: :native)

IO.puts("Counter running. Click + in the GPUI window. Press Ctrl+C twice to exit.")

Stream.repeatedly(fn ->
  Process.sleep(16)
  GPUI.Runtime.drain_events(pid)
end)
|> Stream.run()
