defmodule GettingStarted.HelloWindow.View do
  use GPUI.View

  @impl GPUI.View
  def render(_assigns) do
    ~GPUI"""
    <div class="flex grow items-center justify-center p-8">
      <text class="text-2xl font-semibold">Hello, GPUI</text>
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
         size(420, 240)
         root(GettingStarted.HelloWindow.View)
       end
     ]}
  end
end
