defmodule GettingStarted.HelloWindow.View do
  use GPUI.View

  @impl GPUI.View
  def render(_assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center w-[520px] h-[320px] gap-4 p-8 bg-slate-900">
      <text class="text-white text-3xl font-semibold">Hello from the BEAM</text>
      <text class="text-white text-lg">Elixir owns the state. GPUI draws the window.</text>
      <text class="text-green-500">● Runtime connected</text>
    </div>
    """
  end
end

defmodule GettingStarted.HelloWindow.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Hello GPUI" do
         size(520, 320)
         root(GettingStarted.HelloWindow.View)
       end
     ]}
  end
end
