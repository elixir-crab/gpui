Code.require_file(
  "../../../examples/image_palette/support/image_palette.exs",
  __DIR__
)

defmodule GPUITest.Visual.ImagePalette.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  alias Examples.ImagePalette.Analysis

  @colors [
    {0x0F, 0x17, 0x2A},
    {0x25, 0x63, 0xEB},
    {0x10, 0xB9, 0x81},
    {0xF5, 0x9E, 0x0B},
    {0xEF, 0x44, 0x44},
    {0x8B, 0x5C, 0xF6}
  ]

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :image_palette

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.ImagePalette.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme) do
    %{
      path: "/fixtures/color-blocks.png",
      export_path: "/exports/color-blocks.css",
      result: Analysis.analyze(fixture(), colors: length(@colors))
    }
  end

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Image Palette"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "palette-ready"},
      %{
        name: "selected-color",
        actions: [
          {:dispatch, %{type: :click, window_id: 1, event: "select_color:#F59E0B"}}
        ]
      },
      %{
        name: "loading-replacement",
        actions: [
          {:dispatch, %{type: :click, window_id: 1, event: "load_image"}},
          {:send_view, 1, {:image_progress, 1, 45, "Sampling pixels"}}
        ]
      }
    ]
  end

  defp fixture do
    width = 360
    height = 280
    band_width = div(width, length(@colors))

    data =
      for _y <- 0..(height - 1), x <- 0..(width - 1), into: <<>> do
        {red, green, blue} = Enum.at(@colors, min(div(x, band_width), length(@colors) - 1))
        <<red, green, blue, 255>>
      end

    GPUI.Raster.new(width, height, data)
  end
end
