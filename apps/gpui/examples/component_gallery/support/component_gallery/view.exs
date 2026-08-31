defmodule Examples.ComponentGallery.View do
  use GPUI.View

  alias Examples.ComponentGallery.Catalog
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    visible = visible_stories(assigns.query)
    active = active_story(assigns.story, visible)
    story_state = Map.fetch!(assigns.story_states, active.id)

    ~GPUI"""
    <div class="flex w-full h-full min-h-0 bg-white">
      <UI.sidebar id="gallery-sidebar" collapsible="none" class="w-[248px]">
        <UI.sidebar_header id="gallery-sidebar-header">
          <div class="flex flex-col w-full gap-3">
            <div class="flex flex-col min-w-0">
              <text class="font-semibold text-slate-900">GPUI Components</text>
              <text class="text-sm text-slate-500">Elixir storybook</text>
            </div>
            <UI.input id="gallery-search" label="Search components" value={assigns.query} placeholder="Search…" cleanable={true} phx-change="search_changed" />
          </div>
        </UI.sidebar_header>
        {story_navigation(visible, active.id)}
      </UI.sidebar>

      <div class="flex grow h-full min-w-0 min-h-0 flex-col bg-white">
        <div class="flex items-start justify-between px-6 py-4 border-b border-slate-200">
          <div class="flex flex-col gap-1 min-w-0">
            <text class="text-xl font-semibold text-slate-900">{active.title}</text>
            <text class="text-sm text-slate-500">{active.description}</text>
          </div>
          <UI.button id="reset-story" label="Reset" variant="ghost" disabled={active.id == "welcome"} phx-click="reset_story" />
        </div>

        <scroll class="flex grow h-full min-h-0">
          <div class="flex grow min-h-full p-8">{active.module.render_story(story_state)}</div>
        </scroll>

        <UI.status_bar id="gallery-status">
          <UI.status_item id="gallery-status-left" side="left">
            <text class="text-sm text-slate-500">{length(Catalog.modules())} components</text>
            <UI.separator id="gallery-status-separator" orientation="vertical" />
            <text class="text-sm text-slate-700">{active.title}</text>
          </UI.status_item>
          <UI.status_item id="gallery-status-right" side="right">
            <text class="text-sm text-slate-500">Elixir event {assigns.event_count}</text>
            <text class="text-sm text-slate-600">{assigns.last_event || "ready"}</text>
          </UI.status_item>
        </UI.status_bar>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("search_changed", %{value: query}, assigns) do
    visible = visible_stories(query)

    story =
      if Enum.any?(visible, &(&1.id == assigns.story)), do: assigns.story, else: hd(visible).id

    {:noreply, record(%{assigns | query: query, story: story}, "search_changed")}
  end

  def handle_event("story-" <> story, _event, assigns),
    do: {:noreply, record(%{assigns | story: story}, "selected #{story}")}

  def handle_event("reset_story", _event, assigns) do
    entry = Catalog.fetch!(assigns.story)
    assigns = put_in(assigns, [:story_states, assigns.story], entry.module.initial_state())
    {:noreply, record(assigns, "reset #{assigns.story}")}
  end

  def handle_event("story:" <> route, payload, assigns) do
    [story_id, event] = String.split(route, ":", parts: 2)
    entry = Catalog.fetch!(story_id)
    state = Map.fetch!(assigns.story_states, story_id)

    result =
      if function_exported?(entry.module, :story_event, 3),
        do: entry.module.story_event(event, payload, state),
        else: {:noreply, state}

    case result do
      {:noreply, state} ->
        assigns = put_in(assigns, [:story_states, story_id], state)
        {:noreply, record(assigns, "#{story_id}:#{event}")}
    end
  end

  defp story_navigation(stories, active) do
    stories
    |> Enum.group_by(& &1.group)
    |> Enum.sort_by(fn {group, _} -> group_order(group) end)
    |> Enum.map(fn {group, entries} ->
      assigns = %{group: group, entries: entries, active: active}

      ~GPUI"""
      <UI.sidebar_group id={"group-" <> slug(assigns.group)} label={assigns.group}>
        <UI.sidebar_menu id={"menu-" <> slug(assigns.group)}>
          {Enum.map(assigns.entries, &story_item(&1, assigns.active))}
        </UI.sidebar_menu>
      </UI.sidebar_group>
      """
    end)
  end

  defp story_item(story, active) do
    assigns = %{story: story, active: story.id == active}

    ~GPUI"""
    <UI.sidebar_item id={"story-" <> assigns.story.id} label={assigns.story.title} active={assigns.active} phx-click={"story-" <> assigns.story.id} />
    """
  end

  defp visible_stories(query) do
    query = query |> String.trim() |> String.downcase()

    matches =
      Enum.filter(Catalog.entries(), fn story ->
        query == "" or
          String.contains?(String.downcase(story.title <> " " <> story.description), query)
      end)

    if matches == [], do: Catalog.entries(), else: matches
  end

  defp active_story(id, stories), do: Enum.find(stories, &(&1.id == id)) || hd(stories)
  defp slug(value), do: value |> String.downcase() |> String.replace(" ", "-")
  defp group_order("Getting started"), do: 0
  defp group_order("Components"), do: 1
  defp group_order("Overlays"), do: 2
  defp group_order("Navigation"), do: 3
  defp group_order("Collections"), do: 4

  defp record(assigns, event),
    do: %{assigns | event_count: assigns.event_count + 1, last_event: event}
end
