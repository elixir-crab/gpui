defmodule GPUI.Dev.ExampleLoader do
  @moduledoc "Development loader for compiling and running standalone GPUI examples."

  @project_root Mix.Project.project_file() |> Path.dirname()

  @sources %{
    beam_observatory: "examples/beam_observatory/support/beam_observatory.exs",
    component_gallery: "examples/component_gallery/support/component_gallery.exs",
    elixir_workbench: "examples/elixir_workbench/support/elixir_workbench.exs",
    focus_timer: "examples/getting_started/support/focus_timer.exs",
    hello_window: "examples/getting_started/support/hello_window.exs",
    image_palette: "examples/image_palette/support/image_palette.exs",
    music_library: "examples/music_library/support/music_library.exs",
    resource_ref_image: "examples/features/support/resource_ref_image.exs",
    rich_transcript: "examples/features/rich_transcript.exs",
    settings_form: "examples/getting_started/support/settings_form.exs"
  }

  @spec load!(atom()) :: [{module(), binary()}] | nil
  def load!(name) when is_map_key(@sources, name) do
    @sources
    |> Map.fetch!(name)
    |> then(&Path.join(@project_root, &1))
    |> Code.require_file()
  end
end
