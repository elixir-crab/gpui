# Ultra-minimal remote smoke check.
#
# Run from the repo over SSH:
#   GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix compile
#   ZED_HEADLESS=1 GPUI_REAL_GPUI=1 PATH="$HOME/.cargo/bin:$PATH" mix run examples/remote_check.exs
#
# Expected output:
#   GPUI remote check: PASS

defmodule RemoteCheckView do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center bg-slate-900 text-white text-xl p-4 gap-2">
      <text>Count: {assigns.count}</text>
      <button phx-click="inc" class="bg-blue-600 text-white p-2 rounded-md">+</button>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("inc", _event, assigns) do
    {:noreply, %{assigns | count: assigns.count + 1}}
  end
end

defmodule RemoteCheckApp do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok, %{},
     [
       window "GPUI Remote Check" do
         size(240, 160)
         root(RemoteCheckView, count: 0)
       end
     ]}
  end
end

children = [
  {RemoteCheckApp, backend: :native, poll_interval: 10}
]

{:ok, _supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

pid = Process.whereis(RemoteCheckApp)
[window] = GPUI.Runtime.windows(pid)

{:ok, :ok} =
  GPUI.Runtime.inject_event(pid, %{
    window_id: window.id,
    event: "inc"
  })

deadline = System.monotonic_time(:millisecond) + 1_000

result =
  Stream.repeatedly(fn ->
    Process.sleep(10)
    [updated] = GPUI.Runtime.windows(pid)
    {_module, assigns} = updated.root
    assigns.count
  end)
  |> Enum.find(fn count ->
    count == 1 or System.monotonic_time(:millisecond) > deadline
  end)

if result == 1 do
  IO.puts("GPUI remote check: PASS")
  System.halt(0)
else
  IO.puts(:stderr, "GPUI remote check: FAIL")
  System.halt(1)
end
