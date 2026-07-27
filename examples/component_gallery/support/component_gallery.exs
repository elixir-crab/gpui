defmodule Examples.ComponentGallery.View do
  use GPUI.View

  alias GPUI.UI
  alias GPUI.UI.Overlay

  @stories [
    %{
      id: "actions",
      group: "FOUNDATIONS",
      title: "Buttons & feedback",
      description:
        "Action hierarchy, loading, destructive intent, progress, and clipboard behavior."
    },
    %{
      id: "forms",
      group: "FOUNDATIONS",
      title: "Forms & selection",
      description: "Controlled text, choice, toggle, range, and validation states."
    },
    %{
      id: "overlays",
      group: "INTERACTION",
      title: "Overlays",
      description: "Popover, tooltip, dialog, and menu behavior with controlled open state."
    },
    %{
      id: "navigation",
      group: "INTERACTION",
      title: "Navigation & disclosure",
      description: "Tabs and accordions composed into compact application navigation."
    },
    %{
      id: "collections",
      group: "DATA",
      title: "Collections",
      description: "Virtual lists, sortable tables, trees, and stable selection."
    },
    %{
      id: "code",
      group: "DATA",
      title: "Code & diffs",
      description: "Monospaced source and unified diff presentation with line selection."
    }
  ]

  @impl GPUI.View
  def render(assigns) do
    visible = visible_stories(assigns.query)
    active = active_story(assigns.story, visible)

    ~GPUI"""
    <div class="flex grow w-full" style={[background: {:rgb, 0xF8FAFC}]}>
      <div class="flex flex-col w-[220px] gap-3 p-3" style={[background: {:rgb, 0x0B1220}]}>
        <div class="flex items-center gap-3 p-2">
          <div class="flex items-center justify-center w-[30px] h-[30px] rounded-md" style={[background: {:rgb, 0x2563EB}]}>
            <text class="text-white font-semibold">G</text>
          </div>
          <div class="flex flex-col">
            <text class="text-white font-semibold">GPUI for Elixir</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>Component gallery</text>
          </div>
        </div>

        <UI.input
          id="gallery-search"
          label="Search components"
          value={assigns.query}
          placeholder="Search stories"
          cleanable={true}
          phx-change="search_changed"
        />

        <div class="flex flex-col gap-2">
          {story_navigation(visible, active.id)}
        </div>

        <div class="flex grow" />
        <div class="flex flex-col gap-1 p-3 rounded-lg" style={[background: {:rgb, 0x111827}]}>
          <text class="text-white font-semibold">{length(@stories)} stories</text>
          <text style={[color: {:rgb, 0x94A3B8}]}>One canonical place for native component states.</text>
        </div>
      </div>

      <div class="flex grow flex-col">
        <div class="flex items-center justify-between px-4 py-2" style={[background: {:rgb, 0xFFFFFF}]}>
          <div class="flex flex-col gap-1">
            <text class="text-lg font-semibold" style={[color: {:rgb, 0x0F172A}]}>{active.title}</text>
            <text class="text-sm" style={[color: {:rgb, 0x475569}]}>{active.description}</text>
          </div>
          <div class="flex items-center gap-3">
            <text style={[color: {:rgb, 0x64748B}]}>Interactive, controlled state</text>
            <UI.button id="reset-story" label="Reset story" phx-click="reset_story" />
          </div>
        </div>

        <scroll class="flex grow p-3" style={[background: {:rgb, 0xE2E8F0}]}>
          {story(active.id, assigns)}
        </scroll>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("search_changed", %{value: query}, assigns) do
    visible = visible_stories(query)

    story =
      if Enum.any?(visible, &(&1.id == assigns.story)), do: assigns.story, else: hd(visible).id

    {:noreply, %{assigns | query: query, story: story}}
  end

  def handle_event("story-" <> story, _event, assigns),
    do: {:noreply, reset_story(%{assigns | story: story})}

  def handle_event("reset_story", _event, assigns), do: {:noreply, reset_story(assigns)}
  def handle_event("noop", _event, assigns), do: {:noreply, assigns}

  def handle_event("name_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | name: value}}

  def handle_event("language_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | language: value}}

  def handle_event("framework_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | framework: value}}

  def handle_event("notifications_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | notifications: value}}

  def handle_event("plan_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | plan: value}}

  def handle_event("volume_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | volume: value}}

  def handle_event("tabs_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | tab: value}}

  def handle_event("accordion_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | expanded: value}}

  def handle_event("overlay_changed", %{value: value}, assigns),
    do: {:noreply, %{assigns | overlay: value}}

  def handle_event("show-" <> overlay, _event, assigns),
    do: {:noreply, %{assigns | overlay: overlay}}

  def handle_event("menu_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | menu_result: value, overlay: nil}}

  def handle_event("list_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | list_selected: value}}

  def handle_event("table_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | table_selected: value}}

  def handle_event("table_sorted", %{value: value}, assigns),
    do: {:noreply, %{assigns | table_sort: value}}

  def handle_event("tree_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | tree_selected: value}}

  def handle_event("tree_toggled", %{value: "lib"}, assigns),
    do: {:noreply, %{assigns | tree_expanded: not assigns.tree_expanded}}

  def handle_event("line_selected", %{value: value}, assigns),
    do: {:noreply, %{assigns | line_selected: value}}

  defp story_navigation(stories, active) do
    stories
    |> Enum.group_by(& &1.group)
    |> Enum.sort_by(fn {group, _stories} -> group_order(group) end)
    |> Enum.flat_map(fn {group, stories} ->
      [group_label(group) | Enum.map(stories, &story_button(&1, active))]
    end)
  end

  defp group_label(group) do
    assigns = %{group: group}

    ~GPUI"""
    <text style={[color: {:rgb, 0x64748B}]}>{assigns.group}</text>
    """
  end

  defp story_button(story, active) do
    assigns = %{story: story, active: story.id == active}

    ~GPUI"""
    <UI.button
      id={"story-" <> assigns.story.id}
      label={assigns.story.title}
      variant={if(assigns.active, do: "primary", else: "default")}
      phx-click={"story-" <> assigns.story.id}
    />
    """
  end

  defp story("actions", assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex grow flex-col gap-3">
      {section("Action hierarchy", "Variants communicate priority without changing event semantics.", button_examples())}
      {section("Progress & clipboard", "Feedback remains accessible and controlled by Elixir.", feedback_examples(assigns.assigns))}
    </div>
    """
  end

  defp story("forms", assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex grow gap-3">
      <div class="flex grow flex-col gap-3 p-3 rounded-md" style={[background: {:rgb, 0xFFFFFF}]}>
        <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>Profile controls</text>
        <UI.input id="gallery-name" label="Display name" value={assigns.assigns.name} cleanable={true} phx-change="name_changed" />
        <UI.select id="gallery-language" label="Language" value={assigns.assigns.language} options={[{"Elixir", "elixir"}, {"Rust", "rust"}]} phx-change="language_changed" />
        <UI.combobox id="gallery-framework" label="Framework" value={assigns.assigns.framework} options={["Phoenix", "LiveView", "Ash"]} phx-change="framework_changed" />
      </div>
      <div class="flex grow flex-col gap-3">
        {section("Preferences", "Boolean and exclusive choices.", preference_examples(assigns.assigns))}
        {section("Range", "The value remains application-owned.", range_example(assigns.assigns))}
      </div>
    </div>
    """
  end

  defp story("overlays", assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex grow flex-col gap-5">
      {section("Layered interaction", "Each overlay preserves focus and reports controlled state changes.", overlay_examples(assigns.assigns))}
      <div class="flex p-4 rounded-lg" style={[background: {:rgb, 0xDBEAFE}]}>
        <text style={[color: {:rgb, 0x1E3A8A}]}>Last menu action: {assigns.assigns.menu_result || "None yet"}</text>
      </div>
    </div>
    """
  end

  defp story("navigation", assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex grow flex-col gap-5">
      {section("Tabs", "Switch between application-owned sections.", tabs_example(assigns.assigns))}
      {section("Disclosure", "Multiple accordion sections can remain expanded.", accordion_example(assigns.assigns))}
    </div>
    """
  end

  defp story("collections", assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex grow gap-4">
      <div class="flex flex-col w-[240px] h-[620px] p-3 rounded-lg" style={[background: {:rgb, 0xFFFFFF}]}>
        <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>Virtual list</text>
        {virtual_list(assigns.assigns)}
      </div>
      <div class="flex grow flex-col h-[620px] p-3 rounded-lg" style={[background: {:rgb, 0xFFFFFF}]}>
        <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>Sortable table</text>
        {data_table(assigns.assigns)}
      </div>
      <div class="flex flex-col w-[260px] h-[620px] p-3 rounded-lg" style={[background: {:rgb, 0xFFFFFF}]}>
        <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>Project tree</text>
        {tree(assigns.assigns)}
      </div>
    </div>
    """
  end

  defp story("code", assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex grow flex-col gap-4 p-4 rounded-lg" style={[background: {:rgb, 0xFFFFFF}]}>
      <div class="flex items-center justify-between">
        <div class="flex flex-col">
          <text class="text-lg font-semibold" style={[color: {:rgb, 0x0F172A}]}>lib/gpui/runtime.ex</text>
          <text style={[color: {:rgb, 0x64748B}]}>Unified diff with semantic line kinds</text>
        </div>
        <text style={[color: {:rgb, 0x2563EB}]}>Selected: {assigns.assigns.line_selected || "none"}</text>
      </div>
      {code_viewer(assigns.assigns)}
    </div>
    """
  end

  defp section(title, description, child) do
    assigns = %{title: title, description: description, child: child}

    ~GPUI"""
    <div class="flex flex-col gap-3 p-3 rounded-md" style={[background: {:rgb, 0xFFFFFF}]}>
      <div class="flex flex-col">
        <text class="font-semibold" style={[color: {:rgb, 0x0F172A}]}>{assigns.title}</text>
        <text class="text-sm" style={[color: {:rgb, 0x64748B}]}>{assigns.description}</text>
      </div>
      {assigns.child}
    </div>
    """
  end

  defp button_examples do
    ~GPUI"""
    <div class="flex flex-wrap gap-2">
      <UI.button id="button-default" label="Default" />
      <UI.button id="button-primary" label="Primary" variant="primary" />
      <UI.button id="button-success" label="Success" variant="success" />
      <UI.button id="button-warning" label="Warning" variant="warning" />
      <UI.button id="button-danger" label="Delete" variant="danger" />
      <UI.button id="button-loading" label="Saving" loading={true} />
      <UI.button id="button-disabled" label="Disabled" disabled={true} />
    </div>
    """
  end

  defp feedback_examples(_assigns) do
    ~GPUI"""
    <div class="flex items-center gap-3">
      <div class="flex grow flex-col gap-2">
        <div class="flex justify-between">
          <text style={[color: {:rgb, 0x334155}]}>Deployment</text>
          <text style={[color: {:rgb, 0x2563EB}]}>72%</text>
        </div>
        <UI.progress id="gallery-progress" label="Deployment progress" value={72} max={100} />
      </div>
      <UI.copy_button id="copy-token" label="Copy token" text="gpui_live_42" phx-click="noop" />
    </div>
    """
  end

  defp preference_examples(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-col gap-4">
      <UI.checkbox id="gallery-checkbox" label="Email reports" checked={true} phx-change="noop" />
      <UI.switch id="gallery-switch" label="Desktop notifications" checked={assigns.assigns.notifications} phx-change="notifications_changed" />
      <UI.radio_group id="gallery-plan" label="Plan" value={assigns.assigns.plan} options={[{"Free", "free"}, {"Team", "team"}, %{label: "Enterprise", value: "enterprise", disabled: true}]} orientation="horizontal" phx-change="plan_changed" />
    </div>
    """
  end

  defp range_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text style={[color: {:rgb, 0x334155}]}>Notification volume: {round(assigns.assigns.volume)}%</text>
      <UI.slider id="gallery-volume" label="Notification volume" value={assigns.assigns.volume} min={0} max={100} step={5} phx-change="volume_changed" />
    </div>
    """
  end

  defp overlay_examples(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-wrap gap-3">
      <Overlay.popover id="gallery-popover" label="Quick profile" open={assigns.assigns.overlay == "popover"} phx-change="overlay_changed">
        <:trigger><UI.button id="show-popover" label="Popover" phx-click="show-popover" /></:trigger>
        <:content><div class="flex flex-col gap-2 p-2"><text class="font-semibold">Ada Lovelace</text><text>Platform engineer</text></div></:content>
      </Overlay.popover>
      <Overlay.tooltip id="gallery-tooltip" delay={100}>
        <:trigger><UI.button id="tooltip-trigger" label="Hover for tooltip" /></:trigger>
        <:content>Runs on the native GPUI renderer</:content>
      </Overlay.tooltip>
      <UI.button id="show-dialog" label="Open dialog" variant="primary" phx-click="show-dialog" />
      <Overlay.dialog id="gallery-dialog" open={assigns.assigns.overlay == "dialog"} title="Create workspace" width={420} phx-change="overlay_changed">
        <:content><div class="flex flex-col gap-3 p-2"><UI.input id="dialog-name" label="Workspace name" value="Observatory" phx-change="noop" /><UI.button id="dialog-create" label="Create workspace" variant="primary" phx-click="noop" /></div></:content>
      </Overlay.dialog>
      <Overlay.dropdown_menu id="gallery-menu" label="Workspace actions" open={assigns.assigns.overlay == "menu"} phx-change="overlay_changed" phx-select="menu_selected">
        <:trigger><UI.button id="show-menu" label="Actions menu" phx-click="show-menu" /></:trigger>
        <:item value="duplicate">Duplicate</:item>
        <:item value="pin" checked={true}>Pinned</:item>
        <:item value="archive">Archive</:item>
        <:item value="delete" disabled={true}>Delete permanently</:item>
      </Overlay.dropdown_menu>
    </div>
    """
  end

  defp tabs_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-col gap-4">
      <UI.tabs id="gallery-tabs" value={assigns.assigns.tab} options={[{"Overview", "overview"}, {"Activity", "activity"}, {"Settings", "settings"}]} variant="underline" phx-change="tabs_changed" />
      <div class="flex p-4 rounded-md" style={[background: {:rgb, 0xEFF6FF}]}><text style={[color: {:rgb, 0x1E3A8A}]}>Current section: {assigns.assigns.tab}</text></div>
    </div>
    """
  end

  defp accordion_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <UI.accordion id="gallery-accordion" expanded={assigns.assigns.expanded} multiple={true} phx-change="accordion_changed">
      <UI.accordion_item id="account" title="Account"><text>Identity, sessions, and connected devices.</text></UI.accordion_item>
      <UI.accordion_item id="billing" title="Billing"><text>Invoices and usage thresholds.</text></UI.accordion_item>
      <UI.accordion_item id="security" title="Security"><text>Passkeys and recovery settings.</text></UI.accordion_item>
    </UI.accordion>
    """
  end

  defp virtual_list(assigns) do
    items =
      Enum.map(1..30, fn number ->
        UI.virtual_list_item(%{
          id: "item-#{number}",
          children: ["Build artifact #{String.pad_leading(to_string(number), 2, "0")}"]
        })
      end)

    UI.virtual_list(%{
      id: "gallery-list",
      label: "Build artifacts",
      selected: assigns.list_selected,
      reveal: assigns.list_selected,
      item_height: 42,
      "phx-change": "list_selected",
      class: "grow",
      children: items
    })
  end

  defp data_table(assigns) do
    columns = [
      UI.table_column(%{id: "service", label: "Service", width: 150, sortable: true}),
      UI.table_column(%{id: "status", label: "Status", width: 110}),
      UI.table_column(%{
        id: "latency",
        label: "Latency",
        width: 100,
        align: "right",
        sortable: true
      })
    ]

    rows =
      Enum.map(
        [
          {"api", "Healthy", "38 ms"},
          {"jobs", "Healthy", "72 ms"},
          {"events", "Degraded", "184 ms"},
          {"search", "Healthy", "54 ms"}
        ],
        fn {service, status, latency} ->
          UI.table_row(%{id: service, children: [service, status, latency]})
        end
      )

    UI.data_table(%{
      id: "gallery-table",
      label: "Services",
      selected: assigns.table_selected,
      reveal: assigns.table_selected,
      sort_column: assigns.table_sort,
      sort_direction: "ascending",
      item_height: 48,
      "phx-change": "table_selected",
      "phx-sort": "table_sorted",
      class: "grow",
      children: columns ++ rows
    })
  end

  defp tree(assigns) do
    items = [
      UI.tree_item(%{
        id: "lib",
        level: 1,
        branch: true,
        expanded: assigns.tree_expanded,
        children: ["lib"]
      }),
      UI.tree_item(%{
        id: "lib/gpui",
        parent_id: "lib",
        level: 2,
        branch: true,
        expanded: true,
        children: ["gpui"]
      }),
      UI.tree_item(%{id: "runtime", parent_id: "lib/gpui", level: 3, children: ["runtime.ex"]}),
      UI.tree_item(%{id: "session", parent_id: "lib/gpui", level: 3, children: ["session.ex"]}),
      UI.tree_item(%{id: "test", level: 1, branch: true, expanded: false, children: ["test"]})
    ]

    UI.tree(%{
      id: "gallery-tree",
      label: "Project files",
      selected: assigns.tree_selected,
      reveal: assigns.tree_selected,
      item_height: 42,
      "phx-change": "tree_selected",
      "phx-toggle": "tree_toggled",
      class: "grow",
      children: items
    })
  end

  defp code_viewer(assigns) do
    lines = [
      UI.code_line(%{
        id: "line-1",
        text: "@@ -74,6 +74,10 @@ def refresh(runtime) do",
        kind: "hunk"
      }),
      UI.code_line(%{
        id: "line-2",
        number: 74,
        text: "   snapshot = Session.snapshot(session)",
        kind: "context"
      }),
      UI.code_line(%{
        id: "line-3",
        number: 75,
        text: "-  Display.sync(display, snapshot)",
        kind: "deletion"
      }),
      UI.code_line(%{
        id: "line-4",
        number: 75,
        text: "+  with {:ok, snapshot} <- Session.refresh(session),",
        kind: "addition"
      }),
      UI.code_line(%{
        id: "line-5",
        number: 76,
        text: "+       :ok <- Display.sync(display, snapshot) do",
        kind: "addition"
      }),
      UI.code_line(%{id: "line-6", number: 77, text: "+    {:ok, snapshot}", kind: "addition"}),
      UI.code_line(%{id: "line-7", number: 78, text: "+  end", kind: "addition"})
    ]

    UI.code_viewer(%{
      id: "gallery-code",
      label: "Runtime diff",
      mode: "diff",
      selected: assigns.line_selected,
      reveal: assigns.line_selected,
      item_height: 34,
      max_columns: 110,
      "phx-change": "line_selected",
      class: "grow",
      children: lines
    })
  end

  defp visible_stories(query) do
    query = query |> String.trim() |> String.downcase()

    matches =
      Enum.filter(@stories, fn story ->
        query == "" or
          String.contains?(String.downcase(story.title <> " " <> story.description), query)
      end)

    if matches == [], do: @stories, else: matches
  end

  defp active_story(id, stories), do: Enum.find(stories, &(&1.id == id)) || hd(stories)
  defp group_order("FOUNDATIONS"), do: 0
  defp group_order("INTERACTION"), do: 1
  defp group_order("DATA"), do: 2

  defp reset_story(assigns) do
    Map.merge(assigns, %{
      overlay: nil,
      menu_result: nil,
      name: "Ada Lovelace",
      language: "elixir",
      framework: "Phoenix",
      notifications: true,
      plan: "team",
      volume: 65.0,
      tab: "overview",
      expanded: ["account"],
      list_selected: nil,
      table_selected: nil,
      table_sort: "service",
      tree_selected: nil,
      tree_expanded: true,
      line_selected: nil
    })
  end
end

defmodule Examples.ComponentGallery.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    story = args |> Map.new() |> Map.get(:story, "actions")

    assigns = %{
      story: story,
      query: "",
      overlay: nil,
      menu_result: nil,
      name: "Ada Lovelace",
      language: "elixir",
      framework: "Phoenix",
      notifications: true,
      plan: "team",
      volume: 65.0,
      tab: "overview",
      expanded: ["account"],
      list_selected: nil,
      table_selected: nil,
      table_sort: "service",
      tree_selected: nil,
      tree_expanded: true,
      line_selected: nil
    }

    {:ok,
     [
       window "GPUI Component Gallery" do
         size(1280, 820)
         root(Examples.ComponentGallery.View, assigns)
       end
     ]}
  end
end
