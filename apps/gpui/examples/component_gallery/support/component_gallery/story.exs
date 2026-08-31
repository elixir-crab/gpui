defmodule Examples.ComponentGallery.Story do
  @moduledoc false

  @type metadata :: %{
          id: String.t(),
          group: String.t(),
          title: String.t(),
          description: String.t()
        }

  @callback metadata() :: metadata()
  @callback initial_state() :: map()
  @callback render_story(map()) :: GPUI.Element.t()
  @callback story_event(String.t(), term(), map()) :: {:noreply, map()}

  @optional_callbacks story_event: 3
end
