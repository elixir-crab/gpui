GPUITest.Examples.load!(:music_library)

defmodule GPUI.MusicLibraryExampleTest do
  use GPUI.Test, async: true

  test "searches, selects, and controls playback from Elixir state" do
    runtime = start_gpui!(Examples.MusicLibrary.App)

    assert %{title: "Afterglow Music", size: [1240, 820]} = window_snapshot(runtime)

    assert %{playing_id: "glass-harbor", playing: true, position: 41.0, volume: 70.0} =
             assigns(runtime)

    assert %{type: :ui_virtual_list, attrs: %{selected: "glass-harbor"}} =
             runtime |> tree() |> find!(id: "music-tracks")

    change(runtime, "search_changed", "northline")
    assert %{query: "northline", selected_id: "slow-orbit"} = assigns(runtime)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(&match?(%{children: ["Slow Orbit"]}, &1))

    change(runtime, "track_selected", "blue-room")

    assert %{selected_id: "blue-room", playing_id: "blue-room", playing: true} =
             selected =
             assigns(runtime)

    assert selected.position in [0, 0.0]

    click(runtime, "play-all")
    click(runtime, "toggle_play")
    change(runtime, "seek_changed", 64.0)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(&match?(%{children: ["2:26"]}, &1))

    click(runtime, "volume-down")
    click(runtime, "volume-down")
    click(runtime, "volume-down")

    assert %{
             selected_id: "slow-orbit",
             playing_id: "slow-orbit",
             playing: false,
             position: 64.0,
             volume: 40.0
           } = assigns(runtime)

    click(runtime, "next")

    assert %{playing_id: "blue-room", selected_id: "blue-room", playing: true} =
             assigns(runtime)
  end

  test "switches library sections and handles an empty search" do
    runtime = start_gpui!(Examples.MusicLibrary.App)

    click(runtime, "nav-focus")
    assert %{section: "focus"} = assigns(runtime)

    change(runtime, "search_changed", "not in this collection")

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(&match?(%{children: ["No matching songs"]}, &1))
  end
end
