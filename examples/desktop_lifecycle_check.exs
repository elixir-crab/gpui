# Minimal real-desktop lifecycle smoke check.
#
# Run on a server without a desktop environment:
#
#   xvfb-run -a -s "-screen 0 1280x720x24" \
#     dbus-run-session -- \
#     env VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
#     mix run examples/desktop_lifecycle_check.exs

defmodule DesktopLifecycleCheck do
  alias GPUI.Snapshot

  def run do
    tree_a = tree("runtime A")
    tree_b = tree("runtime B")
    window_a = window(1, "Runtime A", tree_a)
    window_b = window(1, "Runtime B", tree_b)

    {:ok, display_a} = GPUI.Display.Native.start_link([])
    {:ok, display_b} = GPUI.Display.Native.start_link([])

    :ok = GPUI.Display.Native.sync(display_a, snapshot([window_a]))
    :ok = GPUI.Display.Native.sync(display_b, snapshot([window_b]))
    :ok = GPUI.Display.Native.sync(display_a, snapshot([window(1, "Runtime A", tree("A updated"))]))
    :ok = GPUI.Display.Native.sync(display_b, snapshot([window(1, "Runtime B", tree("B updated"))]))

    # Snapshot shrink must issue a real close command and wait for its acknowledgement.
    :ok = GPUI.Display.Native.sync(display_a, snapshot([]))
    :ok = GPUI.Display.Native.sync(display_a, snapshot([window_a]))

    resource_window = window(1, "Runtime A", resource_tree("pixel"))
    red = GPUI.Raster.new(1, 1, <<255, 0, 0, 255>>) |> GPUI.Raster.to_payload()
    blue = GPUI.Raster.new(1, 1, <<0, 0, 255, 255>>) |> GPUI.Raster.to_payload()

    :ok = GPUI.Display.Native.sync(display_a, snapshot([resource_window], %{"pixel" => red}))
    %{"pixel" => ^red} = :sys.get_state(display_a).resources

    :ok = GPUI.Display.Native.sync(display_a, snapshot([resource_window], %{"pixel" => blue}))
    %{"pixel" => ^blue} = :sys.get_state(display_a).resources

    :ok = GPUI.Display.Native.sync(display_a, snapshot([resource_window]))
    %{} = :sys.get_state(display_a).resources

    runtime_a = :sys.get_state(display_a).runtime
    :ok = GenServer.stop(display_a)

    # Shutdown must have removed A's live window, while B remains independently usable.
    {:error, "unknown_window"} = GPUI.Native.update_window(runtime_a, 1, tree_a)
    :ok = GPUI.Display.Native.sync(display_b, snapshot([window(1, "Runtime B", tree("B survived A"))]))

    runtime_b = :sys.get_state(display_b).runtime
    {:ok, 1} = GPUI.Native.close_window(runtime_b, 1)
    {:error, "unknown_window"} = GPUI.Native.close_window(runtime_b, 1)
    :ok = GenServer.stop(display_b)

    IO.puts("GPUI desktop lifecycle check: PASS")
  end

  defp snapshot(windows, resources \\ %{}),
    do: %Snapshot{windows: windows, resources: resources}

  defp window(id, title, tree) do
    %{id: id, title: title, root: %{tree: tree}}
  end

  defp tree(text) do
    %{
      type: :div,
      attrs: %{},
      children: [%{type: :text, attrs: %{}, children: [text]}]
    }
  end

  defp resource_tree(id) do
    %{
      type: :div,
      attrs: %{},
      children: [
        %{
          type: :img,
          attrs: %{raster: %{__type__: :resource_ref, id: id, type: :raster}},
          children: []
        }
      ]
    }
  end

end

DesktopLifecycleCheck.run()
