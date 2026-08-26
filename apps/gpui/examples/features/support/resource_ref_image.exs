defmodule Examples.ResourceRefImage do
  @moduledoc false

  @size 160

  def raster do
    pixels =
      for y <- 0..(@size - 1), x <- 0..(@size - 1), into: <<>> do
        case {x < div(@size, 2), y < div(@size, 2)} do
          {true, true} -> <<37, 99, 235, 255>>
          {false, true} -> <<16, 185, 129, 255>>
          {true, false} -> <<245, 158, 11, 255>>
          {false, false} -> <<239, 68, 68, 255>>
        end
      end

    GPUI.Raster.new(@size, @size, pixels)
  end
end

defmodule Examples.ResourceRefImage.View do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center w-[480px] h-[360px] gap-4 p-8 bg-slate-900">
      <text class="text-white text-2xl font-semibold">Reusable raster resource</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>The snapshot carries a lightweight resource reference.</text>
      <img raster={assigns.preview} label="Four-color raster preview" />
      <text style={[color: {:rgb, 0x86EFAC}]}>160 × 160 RGBA · installed once</text>
    </div>
    """
  end
end

defmodule Examples.ResourceRefImage.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Resource Reference Image" do
         size(480, 360)
         root(Examples.ResourceRefImage.View, preview: GPUI.ResourceRef.new("preview", :raster))
       end
     ]}
  end
end
