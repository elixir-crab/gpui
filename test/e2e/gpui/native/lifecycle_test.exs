defmodule GPUI.Native.LifecycleE2ETest do
  use GPUI.Test, desktop: true

  alias GPUI.Snapshot

  @moduletag :e2e

  test "real windows share one application loop while retaining runtime isolation", %{
    desktop: desktop
  } do
    tree_a = tree("runtime A")
    tree_b = tree("runtime B")
    window_a = window(1, "Runtime A", tree_a)
    window_b = window(1, "Runtime B", tree_b)

    display_a =
      Desktop.start_native_display!()

    display_b =
      Desktop.start_native_display!()

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

    assert {:error, :window_not_found} = GPUI.Display.Native.await_frame(display_a, 999, 100)

    frame_waiters =
      for _index <- 1..3 do
        Task.async(fn -> GPUI.Display.Native.await_frame(display_a, 1) end)
      end

    display_a_window = Desktop.window!(desktop, "Runtime A")
    Desktop.request_frame!(desktop, display_a_window)
    assert [:ok, :ok, :ok] = Enum.map(frame_waiters, &Task.await(&1, 7_000))

    assert {:ok, generation} = GPUI.Display.Native.frame_token(display_a, 1)

    next_frame_waiters =
      for _index <- 1..3 do
        Task.async(fn ->
          GPUI.Display.Native.await_frame_after(display_a, 1, generation)
        end)
      end

    assert :ok = GPUI.Display.Native.sync(display_a, snapshot([resource_window]))
    Desktop.move!(desktop, display_a_window, at: {3, 3})
    assert [:ok, :ok, :ok] = Enum.map(next_frame_waiters, &Task.await(&1, 7_000))

    runtime_a = :sys.get_state(display_a).runtime
    assert :ok = GenServer.stop(display_a)
    assert {:error, "gpui_runtime_stopped"} = GPUI.Native.update_window(runtime_a, 1, tree_a)
    assert {:error, "gpui_runtime_stopped"} = GPUI.Native.await_frame(runtime_a, 1, 100)
    assert {:error, "gpui_runtime_stopped"} = GPUI.Native.frame_token(runtime_a, 1)

    assert {:error, "gpui_runtime_stopped"} =
             GPUI.Native.await_frame_after(runtime_a, 1, 0, 100)

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
    assert {:error, "unknown_window"} = GPUI.Native.await_frame(runtime_b, 1, 100)
    assert {:error, "unknown_window"} = GPUI.Native.frame_token(runtime_b, 1)
    assert {:error, "unknown_window"} = GPUI.Native.await_frame_after(runtime_b, 1, 0, 100)
  end

  test "repeated window and resource reconciliation remains responsive", %{desktop: desktop} do
    title = "Lifecycle stress"
    display = Desktop.start_native_display!()

    assert :ok = GPUI.Display.Native.sync(display, snapshot([window(1, title, tree("initial"))]))
    native_window_id = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, display, 1, native_window_id)

    final_window_id =
      Enum.reduce(1..20, native_window_id, fn iteration, _current_window_id ->
        pixel = stress_pixel(iteration)
        resource_window = window(1, title, resource_tree("pixel"))
        assert {:ok, generation} = GPUI.Display.Native.frame_token(display, 1)

        assert :ok =
                 GPUI.Display.Native.sync(
                   display,
                   snapshot([resource_window], %{"pixel" => pixel})
                 )

        current_window_id = Desktop.window!(desktop, title)
        Desktop.move!(desktop, current_window_id, at: {rem(iteration, 4) + 1, 2})
        assert :ok = GPUI.Display.Native.await_frame_after(display, 1, generation)

        if rem(iteration, 5) == 0 do
          assert :ok = GPUI.Display.Native.sync(display, snapshot([]))

          assert {:ok, events} = GPUI.Display.Native.drain_events(display)
          assert %{type: :window_closed, window_id: 1} in events

          assert :ok =
                   GPUI.Display.Native.sync(
                     display,
                     snapshot([resource_window], %{"pixel" => pixel})
                   )

          reopened_window_id = Desktop.window!(desktop, title)
          Desktop.await_frame!(desktop, display, 1, reopened_window_id)
          reopened_window_id
        else
          current_window_id
        end
      end)

    assert %GPUITest.Desktop.Window{} = final_window_id
    assert Process.alive?(display)
    assert %{windows: windows, resources: resources} = :sys.get_state(display)
    assert Map.keys(windows) == [1]
    assert Map.has_key?(resources, "pixel")
  end

  test "resizing a window schedules and completes a fresh frame", %{desktop: desktop} do
    title = "Lifecycle resize"
    display = Desktop.start_native_display!()

    responsive_tree = %{
      type: :div,
      attrs: %{style: [width: :full, height: :full, background: {:rgb, 0x0F172A}]},
      children: [%{type: :text, attrs: %{}, children: ["responsive"]}]
    }

    assert :ok =
             GPUI.Display.Native.sync(
               display,
               snapshot([window(1, title, responsive_tree)])
             )

    native_window_id = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, display, 1, native_window_id)
    assert {:ok, generation} = GPUI.Display.Native.frame_token(display, 1)

    Desktop.resize!(desktop, native_window_id, to: {700, 460})
    Desktop.await_frame_after!(display, 1, generation)

    assert {:ok, resized_generation} = GPUI.Display.Native.frame_token(display, 1)
    assert resized_generation > generation
    assert Process.alive?(display)
  end

  test "malformed native payloads are rejected without poisoning the runtime", %{desktop: desktop} do
    title = "Malformed payloads"
    display = Desktop.start_native_display!()

    assert :ok = GPUI.Display.Native.sync(display, snapshot([window(1, title, tree("valid"))]))
    native_window_id = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, display, 1, native_window_id)
    runtime = :sys.get_state(display).runtime

    malformed_trees = [
      missing_type: %{},
      unknown_type: %{type: :unknown, attrs: %{}, children: []},
      missing_component_id: %{
        type: :ui_button,
        attrs: %{label: "Missing ID"},
        children: []
      },
      invalid_style: %{type: :div, attrs: %{style: [padding: :invalid]}, children: []},
      invalid_virtual_list_height: %{
        type: :ui_virtual_list,
        attrs: %{id: "invalid-list", label: "Invalid list", item_height: 0},
        children: []
      },
      invalid_virtual_list_count: %{
        type: :ui_virtual_list,
        attrs: %{id: "invalid-count", label: "Invalid list", total_count: -1},
        children: []
      },
      invalid_data_table_column_width: %{
        type: :ui_data_table,
        attrs: %{id: "invalid-table", label: "Invalid table", total_count: 0},
        children: [
          %{
            type: :ui_table_column,
            attrs: %{id: "name", label: "Name", width: 0},
            children: []
          }
        ]
      },
      invalid_code_viewer_tab_width: %{
        type: :ui_code_viewer,
        attrs: %{id: "invalid-code", label: "Invalid code", tab_width: 0},
        children: []
      },
      invalid_code_line_kind: %{
        type: :ui_code_viewer,
        attrs: %{id: "invalid-code-line", label: "Invalid code"},
        children: [
          %{
            type: :ui_code_line,
            attrs: %{id: "line", text: "bad", kind: "fatal"},
            children: []
          }
        ]
      },
      invalid_tree_parent: %{
        type: :ui_tree,
        attrs: %{id: "invalid-tree", label: "Invalid tree", total_count: 1},
        children: [
          %{
            type: :ui_tree_item,
            attrs: %{id: "child", parent_id: 42, level: 2},
            children: []
          }
        ]
      },
      invalid_tree_position: %{
        type: :ui_tree,
        attrs: %{id: "invalid-tree-position", label: "Invalid tree", total_count: 1},
        children: [
          %{type: :ui_tree_item, attrs: %{id: "child", position: -1}, children: []}
        ]
      },
      zero_tree_accessibility_position: %{
        type: :ui_tree,
        attrs: %{id: "zero-tree-position", label: "Invalid tree", total_count: 1},
        children: [
          %{
            type: :ui_tree_item,
            attrs: %{id: "child", level: 0, position: 0, set_size: 0},
            children: []
          }
        ]
      },
      unnamed_slider: %{
        type: :ui_slider,
        attrs: %{id: "unnamed-slider"},
        children: []
      },
      unnamed_input: %{
        type: :ui_input,
        attrs: %{id: "unnamed-input"},
        children: []
      },
      invalid_input_focus_request: %{
        type: :ui_input,
        attrs: %{id: "invalid-input-focus", label: "Invalid input", focus_request: -1},
        children: []
      },
      invalid_progress_max: %{
        type: :ui_progress,
        attrs: %{id: "invalid-progress", label: "Invalid progress", max: 0},
        children: []
      },
      invalid_file_limit: %{
        type: :ui_button,
        attrs: %{
          id: "invalid-picker",
          label: "Invalid picker",
          file_max_bytes: 0,
          "phx-file-read": "selected"
        },
        children: []
      }
    ]

    for {name, malformed} <- malformed_trees do
      assert_native_rejected(name, fn -> GPUI.Native.update_window(runtime, 1, malformed) end)
      assert Process.alive?(display)
    end

    assert_native_rejected(:invalid_resource, fn ->
      GPUI.Native.put_resource(runtime, "bad", %{
        width: 0,
        height: 1,
        format: :rgba8,
        data: <<>>
      })
    end)

    assert :ok =
             GPUI.Display.Native.sync(display, snapshot([window(1, title, tree("recovered"))]))

    Desktop.await_frame!(desktop, display, 1, native_window_id)
    assert Process.alive?(display)
  end

  defp assert_native_rejected(name, fun) do
    result =
      try do
        {:returned, fun.()}
      rescue
        error in [ArgumentError, ErlangError] -> {:raised, error}
      end

    assert match?({:returned, {:error, _reason}}, result) or match?({:raised, _error}, result),
           "expected #{name} to be rejected, got: #{inspect(result)}"
  end

  defp stress_pixel(iteration) do
    red = rem(iteration * 31, 256)
    blue = rem(iteration * 67, 256)
    GPUI.Raster.new(1, 1, <<red, 0, blue, 255>>) |> GPUI.Raster.to_payload()
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
          flex_basis: {:fraction, 0.5},
          flex_grow: 1.0,
          flex_shrink: 0.0,
          overflow: :hidden,
          cursor: :pointer,
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
              line_height: {:px, 24.0},
              white_space: :nowrap,
              text_overflow: :ellipsis,
              text_align: :center
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
