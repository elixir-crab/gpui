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
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok, %{},
     [
       window "GPUI Counter" do
         size(320, 240)
         root(CounterView, count: 0)
       end
     ]}
  end
end

children = [
  {CounterApp, backend: :native, poll_interval: 16}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

IO.puts("Counter running under an OTP supervisor. Click + in the GPUI window. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
