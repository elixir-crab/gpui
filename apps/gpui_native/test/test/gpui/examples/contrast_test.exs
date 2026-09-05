defmodule GPUI.Examples.ContrastTest do
  use ExUnit.Case, async: true

  @minimum_ratio 4.5
  @light_background 0xFFFFFF

  for scenario <-
        ~w(beam_control_room component_gallery controlled_form focus_timer hello_window image_lab pipeline_monitor)a do
    GPUI.Maintainer.Visual.ScenarioLoader.load!(scenario)
  end

  test "explicit example text colors meet normal-text contrast in light scenarios" do
    scenarios =
      :code.all_loaded()
      |> Enum.map(&elem(&1, 0))
      |> Enum.filter(&scenario?/1)

    failures =
      Enum.flat_map(scenarios, fn scenario ->
        runtime =
          start_supervised!(
            {GPUI.Runtime,
             app: scenario.app(),
             args: scenario.args(:light),
             display: GPUI.Test.Display,
             poll_interval: nil},
            id: {scenario, make_ref()}
          )

        tree = GPUI.Runtime.snapshot(runtime).windows |> hd() |> get_in([:root, :tree])
        explicit_failures(tree, nil, @light_background, [to_string(scenario.id())])
      end)

    assert failures == []
  end

  defp scenario?(module) do
    function_exported?(module, :id, 0) and function_exported?(module, :app, 0) and
      function_exported?(module, :args, 1)
  end

  defp explicit_failures(%{type: type} = node, inherited_fg, inherited_bg, path) do
    style = get_in(node, [:attrs, :style]) || []
    foreground = explicit_rgb(style, :color) || inherited_fg
    background = explicit_rgb(style, :background) || inherited_bg
    id = get_in(node, [:attrs, :id])
    path = path ++ [to_string(type) <> if(id, do: "##{id}", else: "")]

    own =
      if (type == :text and foreground) && background &&
           contrast(foreground, background) < @minimum_ratio do
        [
          %{
            path: Enum.join(path, " > "),
            ratio: contrast(foreground, background),
            text: node.children
          }
        ]
      else
        []
      end

    own ++
      Enum.flat_map(
        Map.get(node, :children, []),
        &explicit_failures(&1, foreground, background, path)
      )
  end

  defp explicit_failures(_leaf, _foreground, _background, _path), do: []

  defp explicit_rgb(style, property) do
    case Keyword.get(style, property) do
      [:rgb, value] -> value
      {:rgb, value} -> value
      _other -> nil
    end
  end

  defp contrast(first, second) do
    [high, low] = Enum.sort([luminance(first), luminance(second)], :desc)
    (high + 0.05) / (low + 0.05)
  end

  defp luminance(rgb) do
    [
      Bitwise.band(Bitwise.bsr(rgb, 16), 255),
      Bitwise.band(Bitwise.bsr(rgb, 8), 255),
      Bitwise.band(rgb, 255)
    ]
    |> Enum.map(fn channel ->
      channel = channel / 255
      if channel <= 0.04045, do: channel / 12.92, else: :math.pow((channel + 0.055) / 1.055, 2.4)
    end)
    |> then(fn [red, green, blue] -> 0.2126 * red + 0.7152 * green + 0.0722 * blue end)
  end
end
