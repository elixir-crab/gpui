# Run with:
#   PATH="$HOME/.cargo/bin:$PATH" mix compile
#   PATH="$HOME/.cargo/bin:$PATH" mix run examples/resource_ref_image.exs

import GPUI.Template, only: [sigil_GPUI: 2]

raster = %GPUI.Raster{
  width: 2,
  height: 2,
  format: :rgba8,
  data: <<
    255, 0, 0, 255,
    0, 255, 0, 255,
    0, 0, 255, 255,
    255, 255, 0, 255
  >>
}

defmodule ResourceRefImageExample.View do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center gap-3 p-4 bg-slate-900 text-white">
      <text>Native resource-ref image</text>
      <img raster={assigns.logo} />
    </div>
    """
  end
end

defmodule ResourceRefImageExample.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Resource ref image" do
         root(ResourceRefImageExample.View, logo: GPUI.ResourceRef.new("logo", :raster))
       end
     ]}
  end
end

{:ok, runtime} = GPUI.Runtime.start_link(app: ResourceRefImageExample.App)
:ok = GPUI.Runtime.put_resource(runtime, "logo", GPUI.Raster.to_payload(raster))

Process.sleep(:infinity)
