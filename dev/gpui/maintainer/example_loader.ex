defmodule GPUI.Maintainer.ExampleLoader do
  @moduledoc "Development loader for compiling and running standalone GPUI examples."

  @project_root GPUI.Maintainer.Paths.app(:gpui)

  @sources %{
    beam_control_room: "examples/beam_control_room/support/beam_control_room.exs",
    component_gallery: "examples/component_gallery/support/component_gallery.exs",
    events: "examples/getting_started/support/events.exs",
    focus_timer: "examples/getting_started/support/focus_timer.exs",
    hello_window: "examples/getting_started/support/hello_window.exs",
    image_lab: "examples/image_lab/support/image_lab.exs",
    multiple_windows: "examples/getting_started/support/multiple_windows.exs",
    pipeline_monitor: "examples/pipeline_monitor/support/pipeline_monitor.exs",
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
