defmodule GPUI.Dev.ExampleLoader do
  @moduledoc "Development loader for compiling and running standalone GPUI examples."

  @project_root GPUI.Dev.Paths.app(:gpui)

  @sources %{
    beam_control_room: "examples/beam_control_room/support/beam_control_room.exs",
    component_gallery: "examples/component_gallery/support/component_gallery.exs",
    elixir_workbench: "examples/elixir_workbench/support/elixir_workbench.exs",
    events: "examples/getting_started/support/events.exs",
    focus_timer: "examples/getting_started/support/focus_timer.exs",
    hello_window: "examples/getting_started/support/hello_window.exs",
    image_palette: "examples/image_palette/support/image_palette.exs",
    multiple_windows: "examples/getting_started/support/multiple_windows.exs",
    music_library: "examples/music_library/support/music_library.exs",
    presentation_primitives: "examples/features/presentation_primitives.exs",
    resource_ref_image: "examples/features/support/resource_ref_image.exs",
    rich_transcript: "examples/features/rich_transcript.exs",
    controlled_form: "examples/getting_started/support/controlled_form.exs"
  }

  @spec load!(atom()) :: [{module(), binary()}] | nil
  def load!(name) when is_map_key(@sources, name) do
    @sources
    |> Map.fetch!(name)
    |> then(&Path.join(@project_root, &1))
    |> Code.require_file()
  end
end
