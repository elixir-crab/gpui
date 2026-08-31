defmodule Examples.MusicLibrary.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    tracks = visible_tracks(assigns)
    selected = selected_track(assigns, tracks)
    playing = track_by_id(assigns.tracks, assigns.playing_id)

    ~GPUI"""
    <div class="flex grow w-full bg-slate-900">
      <div class="flex flex-col w-[180px] gap-3 p-3" style={[background: {:rgb, 0x0B1220}]}>
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center w-[32px] h-[32px] rounded-md" style={[background: {:rgb, 0x7C3AED}]}>
            <text class="text-white font-semibold">A</text>
          </div>
          <div class="flex flex-col">
            <text class="text-white text-lg font-semibold">Afterglow</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>Music library</text>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <text style={[color: {:rgb, 0x94A3B8}]}>LIBRARY</text>
          {nav_item("Songs", "songs", assigns.section)}
          {nav_item("Albums", "albums", assigns.section)}
          {nav_item("Artists", "artists", assigns.section)}
        </div>

        <div class="flex flex-col gap-2">
          <text style={[color: {:rgb, 0x94A3B8}]}>PLAYLISTS</text>
          {nav_item("Evening focus", "focus", assigns.section)}
          {nav_item("Quiet mornings", "morning", assigns.section)}
          {nav_item("Night drive", "drive", assigns.section)}
        </div>

        <div class="flex grow" />
        <div class="flex flex-col gap-2 p-3 rounded-lg" style={[background: {:rgb, 0x111827}]}>
          <text class="text-white font-semibold">Local collection</text>
          <text style={[color: {:rgb, 0x94A3B8}]}>{length(assigns.tracks)} songs · 1 hr 9 min</text>
          <div class="flex justify-between">
            <text class="text-white font-semibold">Library indexed</text>
            <text style={[color: {:rgb, 0xA78BFA}]}>92%</text>
          </div>
          <div class="flex h-[8px] rounded-full" style={[background: {:rgb, 0x334155}]}>
            <div class="h-[8px] w-[180px] rounded-full" style={[background: {:rgb, 0x8B5CF6}]} />
          </div>
        </div>
      </div>

      <div class="flex grow flex-col">
        <div class="flex items-center justify-between gap-3 px-3 py-2" style={[background: {:rgb, 0x111827}]}>
          <UI.input
            id="music-search"
            label="Search music"
            value={assigns.query}
            placeholder="Search songs, artists, albums"
            cleanable={true}
            phx-change="search_changed"
          />
          <div class="flex gap-2">
            <UI.button id="shuffle" label="Shuffle" phx-click="shuffle" />
            <UI.button id="play-all" label="Play all" variant="primary" phx-click="play-all" />
          </div>
        </div>

        <div class="flex grow h-[600px]">
          <div class="flex grow flex-col gap-2 p-3">
            <div class="flex items-end justify-between">
              <div class="flex flex-col gap-1">
                <text class="text-white text-lg font-semibold">{section_title(assigns.section)}</text>
                <text style={[color: {:rgb, 0x94A3B8}]}>{collection_summary(tracks, assigns.query)}</text>
              </div>
              <UI.select
                id="music-sort"
                label="Sort tracks"
                value={assigns.sort}
                options={[{"Recently added", "recent"}, {"Title", "title"}, {"Artist", "artist"}]}
                phx-change="sort_changed"
              />
            </div>

            {track_list(tracks, assigns.selected_id)}
          </div>

          <scroll class="flex flex-col w-[260px] gap-3 p-3" style={[background: {:rgb, 0x0F172A}]}>
            {now_playing(playing, assigns.playing)}
            {track_details(selected)}
          </scroll>
        </div>

        {player_bar(playing, assigns)}
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("search_changed", %{value: query}, assigns) do
    tracks = visible_tracks(assigns.tracks, %{assigns | query: query})
    selected_id = if Enum.any?(tracks, &(&1.id == assigns.selected_id)), do: assigns.selected_id
    selected_id = selected_id || track_id(List.first(tracks), nil)
    {:noreply, %{assigns | query: query, selected_id: selected_id}}
  end

  def handle_event("sort_changed", %{value: sort}, assigns),
    do: {:noreply, %{assigns | sort: sort}}

  def handle_event("track_selected", %{value: id}, assigns),
    do: {:noreply, select_and_play(assigns, id)}

  def handle_event("play-track-" <> id, _event, assigns),
    do: {:noreply, select_and_play(assigns, id)}

  def handle_event("toggle_play", _event, assigns),
    do: {:noreply, %{assigns | playing: not assigns.playing}}

  def handle_event("play-all", _event, assigns) do
    id = assigns.tracks |> visible_tracks(assigns) |> List.first() |> track_id(assigns.playing_id)
    {:noreply, %{assigns | playing_id: id, selected_id: id, playing: true, position: 0.0}}
  end

  def handle_event("shuffle", _event, assigns) do
    id = assigns.tracks |> Enum.reverse() |> List.first() |> track_id(assigns.playing_id)
    {:noreply, %{assigns | playing_id: id, selected_id: id, playing: true, position: 0.0}}
  end

  def handle_event("previous", _event, assigns), do: {:noreply, step_track(assigns, -1)}
  def handle_event("next", _event, assigns), do: {:noreply, step_track(assigns, 1)}

  def handle_event("seek_changed", %{value: position}, assigns),
    do: {:noreply, %{assigns | position: position}}

  def handle_event("volume-down", _event, assigns),
    do: {:noreply, %{assigns | volume: max(assigns.volume - 10, 0)}}

  def handle_event("volume-up", _event, assigns),
    do: {:noreply, %{assigns | volume: min(assigns.volume + 10, 100)}}

  def handle_event("volume_changed", %{value: volume}, assigns),
    do: {:noreply, %{assigns | volume: volume}}

  def handle_event("nav-" <> section, _event, assigns),
    do: {:noreply, %{assigns | section: section, query: ""}}

  defp nav_item(label, id, selected) do
    assigns = %{label: label, id: id, selected: selected == id}

    ~GPUI"""
    <UI.button
      id={"nav-" <> assigns.id}
      label={assigns.label}
      variant={if(assigns.selected, do: "primary", else: "default")}
      phx-click={"nav-" <> assigns.id}
    />
    """
  end

  defp track_list([], _selected_id) do
    ~GPUI"""
    <div class="flex grow flex-col items-center justify-center gap-2">
      <text class="text-white text-lg font-semibold">No matching songs</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Try a different title, artist, or album.</text>
    </div>
    """
  end

  defp track_list(tracks, selected_id) do
    items = Enum.map(tracks, &track_item/1)

    ~GPUI"""
    <UI.virtual_list
      id="music-tracks"
      label="Music tracks"
      selected={selected_id}
      reveal={selected_id}
      item_height={48}
      phx-change="track_selected"
      class="grow"
    >
      {items}
    </UI.virtual_list>
    """
  end

  defp track_item(track) do
    UI.virtual_list_item(%{
      id: track.id,
      style: [
        display: :flex,
        align_items: :center,
        gap: {:px, 12},
        padding_x: {:px, 12}
      ],
      children: [
        album_art(track),
        track_identity(track),
        text_cell(track.album, 0x94A3B8),
        text_cell(track.year, 0x94A3B8),
        text_cell(track.duration, 0xCBD5E1),
        UI.button(%{
          id: "play-track-" <> track.id,
          label: "Play",
          compact: true,
          "phx-click": "play-track-" <> track.id
        })
      ]
    })
  end

  defp album_art(track) do
    assigns = %{initials: track.initials, color: track.color}

    ~GPUI"""
    <div class="flex items-center justify-center w-[32px] h-[32px] rounded-sm" style={[background: {:rgb, assigns.color}]}>
      <text class="text-white font-semibold">{assigns.initials}</text>
    </div>
    """
  end

  defp track_identity(track) do
    assigns = %{title: track.title, artist: track.artist}

    ~GPUI"""
    <div class="flex flex-col w-[190px]">
      <text class="text-white font-semibold">{assigns.title}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.artist}</text>
    </div>
    """
  end

  defp text_cell(value, color) do
    assigns = %{value: value, color: color}

    ~GPUI"""
    <div class="flex w-[100px]"><text style={[color: {:rgb, assigns.color}]}>{assigns.value}</text></div>
    """
  end

  defp now_playing(track, playing) do
    assigns = %{track: track, playing: playing}

    ~GPUI"""
    <div class="flex flex-col gap-4">
      <div class="flex items-center justify-between">
        <text style={[color: {:rgb, 0x94A3B8}]}>NOW PLAYING</text>
        <text style={[color: {:rgb, 0x22C55E}]}>{if(assigns.playing, do: "● LIVE", else: "PAUSED")}</text>
      </div>
      <div class="flex items-center justify-center h-[140px] rounded-md" style={[background: {:rgb, assigns.track.color}]}>
        <text class="text-white text-3xl font-semibold">{assigns.track.initials}</text>
      </div>
      <div class="flex flex-col gap-1">
        <text class="text-white font-semibold">{assigns.track.title}</text>
        <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.track.artist}</text>
      </div>
    </div>
    """
  end

  defp track_details(nil) do
    ~GPUI"""
    <div class="flex flex-col gap-2 p-4 rounded-lg" style={[background: {:rgb, 0x111827}]}>
      <text class="text-white font-semibold">Track details</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Select a track to inspect it.</text>
    </div>
    """
  end

  defp track_details(track) do
    assigns = %{track: track}

    ~GPUI"""
    <div class="flex flex-col gap-2 p-4 rounded-lg" style={[background: {:rgb, 0x111827}]}>
      <text class="text-white font-semibold">Track details</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Album · {assigns.track.album}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Released · {assigns.track.year}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Duration · {assigns.track.duration}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Quality · Lossless</text>
    </div>
    """
  end

  defp player_bar(track, assigns) do
    player = %{track: track, assigns: assigns}

    ~GPUI"""
    <div class="flex items-center gap-3 h-[104px] px-3 py-2" style={[background: {:rgb, 0xE2E8F0}]}>
      <div class="flex items-center gap-3 w-[250px]">
        {album_art(player.track)}
        <div class="flex flex-col">
          <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>{player.track.title}</text>
          <text style={[color: {:rgb, 0x475569}]}>{player.track.artist}</text>
        </div>
      </div>

      <div class="flex grow flex-col gap-3">
        <div class="flex items-center justify-center gap-3">
          <UI.button id="previous" label="Previous" phx-click="previous" />
          <UI.button
            id="toggle-play"
            label={if(player.assigns.playing, do: "Pause", else: "Play")}
            variant="primary"
            phx-click="toggle_play"
          />
          <UI.button id="next" label="Next" phx-click="next" />
        </div>
        <div class="flex items-center gap-3">
          <div class="flex w-[44px] justify-end">
            <text class="font-semibold" style={[color: {:rgb, 0x334155}]}>{elapsed_time(player.track, player.assigns.position)}</text>
          </div>
          <div class="flex grow">
            <UI.slider
              id="seek"
              label="Playback position"
              value={player.assigns.position}
              min={0}
              max={100}
              step={1}
              phx-change="seek_changed"
              class="grow"
            />
          </div>
          <div class="flex w-[44px]">
            <text class="font-semibold" style={[color: {:rgb, 0x334155}]}>{player.track.duration}</text>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-center gap-2 w-[220px] p-3 rounded-lg" style={[background: {:rgb, 0xCBD5E1}]}>
        <UI.button id="volume-down" label="−" phx-click="volume-down" />
        <div class="flex flex-col items-center w-[72px]">
          <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>Volume</text>
          <text style={[color: {:rgb, 0x334155}]}>{round(player.assigns.volume)}%</text>
        </div>
        <UI.button id="volume-up" label="+" phx-click="volume-up" />
      </div>
    </div>
    """
  end

  defp visible_tracks(assigns), do: visible_tracks(assigns.tracks, assigns)

  defp visible_tracks(tracks, assigns) do
    query = assigns.query |> String.trim() |> String.downcase()

    tracks
    |> Enum.filter(fn track ->
      query == "" or
        Enum.any?([track.title, track.artist, track.album], fn value ->
          value |> String.downcase() |> String.contains?(query)
        end)
    end)
    |> sort_tracks(assigns.sort)
  end

  defp sort_tracks(tracks, "title"), do: Enum.sort_by(tracks, & &1.title)
  defp sort_tracks(tracks, "artist"), do: Enum.sort_by(tracks, &{&1.artist, &1.title})
  defp sort_tracks(tracks, _sort), do: Enum.sort_by(tracks, & &1.added, :desc)

  defp selected_track(assigns, tracks),
    do: track_by_id(tracks, assigns.selected_id) || List.first(tracks)

  defp track_by_id(tracks, id), do: Enum.find(tracks, &(&1.id == id)) || List.first(tracks)
  defp track_id(nil, fallback), do: fallback
  defp track_id(track, _fallback), do: track.id

  defp step_track(assigns, step) do
    tracks = visible_tracks(assigns)
    index = Enum.find_index(tracks, &(&1.id == assigns.playing_id)) || 0
    next = Enum.at(tracks, Integer.mod(index + step, length(tracks)))
    %{assigns | playing_id: next.id, selected_id: next.id, playing: true, position: 0.0}
  end

  defp select_and_play(assigns, id) do
    if Enum.any?(assigns.tracks, &(&1.id == id)) do
      %{assigns | selected_id: id, playing_id: id, playing: true, position: 0.0}
    else
      assigns
    end
  end

  defp elapsed_time(track, position) do
    seconds = round(duration_seconds(track.duration) * position / 100)
    padded_seconds = seconds |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{Kernel.div(seconds, 60)}:#{padded_seconds}"
  end

  defp duration_seconds(duration) do
    [minutes, seconds] = duration |> String.split(":") |> Enum.map(&String.to_integer/1)
    minutes * 60 + seconds
  end

  defp collection_summary(tracks, ""), do: "#{length(tracks)} songs in your collection"
  defp collection_summary(tracks, query), do: "#{length(tracks)} results for “#{query}”"

  defp section_title("songs"), do: "Songs"
  defp section_title("albums"), do: "Albums · all songs"
  defp section_title("artists"), do: "Artists · all songs"
  defp section_title("focus"), do: "Evening focus"
  defp section_title("morning"), do: "Quiet mornings"
  defp section_title("drive"), do: "Night drive"
  defp section_title(_section), do: "Music"
end

defmodule Examples.MusicLibrary.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    tracks = [
      track(
        "glass-harbor",
        "Glass Harbor",
        "Mira Vale",
        "After Images",
        "4:12",
        "2026",
        "GV",
        0x7C3AED,
        6
      ),
      track(
        "slow-orbit",
        "Slow Orbit",
        "Northline",
        "Signal Bloom",
        "3:48",
        "2025",
        "SO",
        0x2563EB,
        5
      ),
      track(
        "paper-suns",
        "Paper Suns",
        "The Soft Hours",
        "Daybreak",
        "5:06",
        "2024",
        "PS",
        0xC2410C,
        4
      ),
      track(
        "night-bus",
        "Night Bus Home",
        "June Arcade",
        "Streetlight",
        "3:31",
        "2026",
        "NB",
        0xDB2777,
        3
      ),
      track(
        "still-water",
        "Still Water",
        "Mira Vale",
        "After Images",
        "4:44",
        "2026",
        "SW",
        0x0E7490,
        2
      ),
      track(
        "blue-room",
        "The Blue Room",
        "Northline",
        "Signal Bloom",
        "3:57",
        "2025",
        "BR",
        0x4F46E5,
        1
      ),
      track(
        "warm-static",
        "Warm Static",
        "June Arcade",
        "Streetlight",
        "3:22",
        "2026",
        "WS",
        0x047857,
        0
      )
    ]

    {:ok,
     [
       window "Afterglow Music" do
         size(1240, 820)

         root(Examples.MusicLibrary.View,
           tracks: tracks,
           section: "songs",
           query: "",
           sort: "recent",
           selected_id: "glass-harbor",
           playing_id: "glass-harbor",
           playing: true,
           position: 41.0,
           volume: 70.0
         )
       end
     ]}
  end

  defp track(id, title, artist, album, duration, year, initials, color, added),
    do: %{
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      year: year,
      initials: initials,
      color: color,
      added: added
    }
end
