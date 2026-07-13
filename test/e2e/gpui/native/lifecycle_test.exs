defmodule GPUI.Native.LifecycleE2ETest do
  use ExUnit.Case, async: false

  alias GPUI.Snapshot
  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  test "real windows share one application loop while retaining runtime isolation" do
    tree_a = tree("runtime A")
    tree_b = tree("runtime B")
    window_a = window(1, "Runtime A", tree_a)
    window_b = window(1, "Runtime B", tree_b)

    {:ok, display_a} = GPUI.Display.Native.start_link([])
    {:ok, display_b} = GPUI.Display.Native.start_link([])
    on_exit(fn -> Desktop.stop_process(display_a) end)
    on_exit(fn -> Desktop.stop_process(display_b) end)

    assert :ok = GPUI.Display.Native.sync(display_a, snapshot([window_a]))
    assert :ok = GPUI.Display.Native.sync(display_b, snapshot([window_b]))

    assert :ok =
             GPUI.Display.Native.sync(
               display_a,
               snapshot([window(1, "Runtime A", tree("A updated"))])
             )

    assert :ok =
             GPUI.Display.Native.sync(
               display_b,
               snapshot([window(1, "Runtime B", expanded_style_tree())])
             )

    assert :ok = GPUI.Display.Native.sync(display_a, snapshot([]))
    assert :ok = GPUI.Display.Native.sync(display_a, snapshot([window_a]))

    resource_window = window(1, "Runtime A", resource_tree("pixel"))
    red = GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>) |> GPUI.Raster.to_payload()
    blue = GPUI.Raster.new(1, 1, <<0, 0, 255, 255>>) |> GPUI.Raster.to_payload()

    assert :ok =
             GPUI.Display.Native.sync(display_a, snapshot([resource_window], %{"pixel" => red}))

    assert %{"pixel" => ^red} = :sys.get_state(display_a).resources

    assert :ok =
             GPUI.Display.Native.sync(display_a, snapshot([resource_window], %{"pixel" => blue}))

    assert %{"pixel" => ^blue} = :sys.get_state(display_a).resources
    assert :ok = GPUI.Display.Native.sync(display_a, snapshot([resource_window]))
    assert %{} = :sys.get_state(display_a).resources

    runtime_a = :sys.get_state(display_a).runtime
    assert :ok = GenServer.stop(display_a)
    assert {:error, "gpui_runtime_stopped"} = GPUI.Native.update_window(runtime_a, 1, tree_a)

    assert :ok =
             GPUI.Display.Native.sync(
               display_b,
               snapshot([window(1, "Runtime B", tree("B survived A"))])
             )

    runtime_b = :sys.get_state(display_b).runtime
    assert {:ok, 1} = GPUI.Native.close_window(runtime_b, 1)

    assert {:ok, [%{type: :window_closed, window_id: 1}]} =
             GPUI.Display.Native.drain_events(display_b)

    assert {:error, "unknown_window"} = GPUI.Native.close_window(runtime_b, 1)
  end

  defp snapshot(windows, resources \\ %{}),
    do: %Snapshot{windows: windows, resources: resources}

  defp window(id, title, tree), do: %{id: id, title: title, root: %{tree: tree}}

  defp tree(text) do
    %{
      type: :div,
      attrs: %{},
      children: [%{type: :text, attrs: %{}, children: [text]}]
    }
  end

  defp expanded_style_tree do
    %{
      type: :div,
      attrs: %{
        style: [
          display: :grid,
          flex_direction: :row_reverse,
          align_items: :stretch,
          justify_content: :between,
          flex_wrap: :wrap,
          flex_grow: 1.0,
          flex_shrink: 0.0,
          opacity: 0.9,
          padding_x: {:px, 8.0},
          padding_y: {:px, 4.0},
          margin_bottom: {:px, 2.0},
          min_width: {:px, 40.0},
          max_height: {:px, 120.0},
          border_width: {:px, 1.0},
          border_color: {:rgb, 0x3B82F6}
        ]
      },
      children: [
        %{
          type: :text,
          attrs: %{
            style: [
              color: {:rgb, 0xFFFFFF},
              font_size: {:px, 18.0},
              font_weight: :bold,
              line_height: {:px, 24.0}
            ]
          },
          children: ["Expanded styles"]
        }
      ]
    }
  end

  defp resource_tree(id) do
    %{
      type: :div,
      attrs: %{},
      children: [
        %{
          type: :img,
          attrs: %{
            raster: %{__type__: :resource_ref, id: id, type: :raster},
            style: [width: {:px, 24.0}, height: {:px, 24.0}]
          },
          children: []
        }
      ]
    }
  end
end
