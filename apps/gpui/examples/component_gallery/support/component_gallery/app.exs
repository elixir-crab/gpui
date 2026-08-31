defmodule Examples.ComponentGallery.App do
  use GPUI.Application

  alias Examples.ComponentGallery.Catalog

  @impl GPUI.Application
  def mount(args) do
    story = args |> Map.new() |> Map.get(:story, "welcome")
    Catalog.fetch!(story)

    assigns = %{
      story: story,
      query: "",
      event_count: 0,
      last_event: nil,
      story_states: Catalog.initial_states()
    }

    {:ok,
     [
       window "GPUI Component Gallery" do
         size(1180, 760)
         root(Examples.ComponentGallery.View, assigns)
       end
     ]}
  end
end
