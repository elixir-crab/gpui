defmodule Examples.ComponentGallery.View do
  use GPUI.View

  alias GPUI.UI
  alias GPUI.UI.Overlay

  @stories [
    %{
      id: "welcome",
      group: "Getting started",
      title: "Introduction",
      description: "Native components with state and events owned by an Elixir view process."
    },
    %{
      id: "button",
      group: "Components",
      title: "Button",
      description: "Action hierarchy, disabled state, and loading feedback."
    },
    %{
      id: "progress",
      group: "Components",
      title: "Progress",
      description: "Bounded progress with an accessible label."
    },
    %{
      id: "input",
      group: "Components",
      title: "Input",
      description: "Controlled text input and cleanable state."
    },
    %{
      id: "select",
      group: "Components",
      title: "Select & combobox",
      description: "Fixed and searchable application-owned choices."
    },
    %{
      id: "checkbox",
      group: "Components",
      title: "Checkbox",
      description: "A controlled boolean field."
    },
    %{
      id: "switch",
      group: "Components",
      title: "Switch",
      description: "Immediate preference state backed by Elixir assigns."
    },
    %{
      id: "radio",
      group: "Components",
      title: "Radio group",
      description: "Exclusive choices with disabled options."
    },
    %{
      id: "slider",
      group: "Components",
      title: "Slider",
      description: "A bounded numeric value controlled by the view."
    },
    %{
      id: "popover",
      group: "Overlays",
      title: "Popover",
      description: "Controlled lightweight content anchored to a trigger."
    },
    %{
      id: "tooltip",
      group: "Overlays",
      title: "Tooltip",
      description: "Delayed contextual help without application state."
    },
    %{
      id: "dialog",
      group: "Overlays",
      title: "Dialog",
      description: "Controlled modal presentation and focus management."
    },
    %{
      id: "menu",
      group: "Overlays",
      title: "Dropdown menu",
      description: "A bounded set of commands and checked states."
    },
    %{
      id: "tabs",
      group: "Navigation",
      title: "Tabs",
      description: "Roving focus and controlled section selection."
    },
    %{
      id: "accordion",
      group: "Navigation",
      title: "Accordion",
      description: "Multiple controlled disclosure sections."
    },
    %{
      id: "virtual_list",
      group: "Collections",
      title: "Virtual list",
      description: "Stable selection over a larger item set."
    },
    %{
      id: "data_table",
      group: "Collections",
      title: "Data table",
      description: "Sortable columns and controlled row selection."
    },
    %{
      id: "tree",
      group: "Collections",
      title: "Tree",
      description: "Hierarchical navigation with controlled expansion."
    },
    %{
      id: "code_viewer",
      group: "Collections",
      title: "Code viewer",
      description: "Selectable semantic lines in a unified diff."
    }
  ]

  @impl GPUI.View
  def render(assigns) do
    visible = visible_stories(assigns.query)
    active = active_story(assigns.story, visible)

    ~GPUI"""
    <div class="flex grow w-full bg-white">
      <div class="flex flex-col w-[248px] min-h-0 border-r border-slate-200 bg-slate-50">
        <div class="flex items-center gap-3 px-4 py-4 border-b border-slate-200">
          <div class="flex items-center justify-center w-[28px] h-[28px] rounded-md bg-slate-900">
            <text class="text-white font-semibold">G</text>
          </div>
          <div class="flex flex-col min-w-0">
            <text class="font-semibold text-slate-900">GPUI Components</text>
            <text class="text-sm text-slate-500">Elixir storybook</text>
          </div>
        </div>

        <div class="p-3">
          <UI.input id="gallery-search" label="Search components" value={assigns.query} placeholder="Search…" cleanable={true} phx-change="search_changed" />
        </div>

        <scroll class="flex grow min-h-0 px-2 pb-3">
          <div class="flex flex-col gap-1">
            {story_navigation(visible, active.id)}
          </div>
        </scroll>
      </div>

      <div class="flex grow min-w-0 flex-col bg-white">
        <div class="flex items-start justify-between px-6 py-4 border-b border-slate-200">
          <div class="flex flex-col gap-1 min-w-0">
            <text class="text-xl font-semibold text-slate-900">{active.title}</text>
            <text class="text-sm text-slate-500">{active.description}</text>
          </div>
          <UI.button id="reset-story" label="Reset" variant="ghost" phx-click="reset_story" />
        </div>

        <scroll class="flex grow min-h-0">
          <div class="flex grow min-h-full p-8">
            {story(active.id, assigns)}
          </div>
        </scroll>

        <div class="flex items-center justify-between px-4 py-2 border-t border-slate-200 bg-slate-50">
          <div class="flex items-center gap-3">
            <text class="text-sm text-slate-500">{length(@stories)} components</text>
            <text class="text-sm text-slate-400">•</text>
            <text class="text-sm text-slate-700">{active.title}</text>
          </div>
          <div class="flex items-center gap-3">
            <text class="text-sm text-slate-500">Elixir event {assigns.event_count}</text>
            <text class="text-sm text-slate-400">{assigns.last_event || "ready"}</text>
          </div>
        </div>
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
    do: {:noreply, record(%{assigns | story: story, overlay: nil}, "selected #{story}")}

  def handle_event("reset_story", _event, assigns),
    do: {:noreply, assigns |> reset_story() |> record("reset #{assigns.story}")}

  def handle_event("noop", _event, assigns), do: {:noreply, record(assigns, "action")}

  def handle_event("name_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | name: value}, "name_changed")}

  def handle_event("language_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | language: value}, "language_changed")}

  def handle_event("framework_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | framework: value}, "framework_changed")}

  def handle_event("reports_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | reports: value}, "reports_changed")}

  def handle_event("notifications_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | notifications: value}, "notifications_changed")}

  def handle_event("plan_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | plan: value}, "plan_changed")}

  def handle_event("volume_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | volume: value}, "volume_changed")}

  def handle_event("tabs_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | tab: value}, "tabs_changed")}

  def handle_event("accordion_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | expanded: value}, "accordion_changed")}

  def handle_event("overlay_changed", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | overlay: value}, "overlay_changed")}

  def handle_event("show-" <> overlay, _event, assigns),
    do: {:noreply, record(%{assigns | overlay: overlay}, "opened #{overlay}")}

  def handle_event("menu_selected", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | menu_result: value, overlay: nil}, "menu: #{value}")}

  def handle_event("list_selected", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | list_selected: value}, "selected #{value}")}

  def handle_event("table_selected", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | table_selected: value}, "selected #{value}")}

  def handle_event("table_sorted", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | table_sort: value}, "sorted #{value}")}

  def handle_event("tree_selected", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | tree_selected: value}, "selected #{value}")}

  def handle_event("tree_toggled", %{value: "lib"}, assigns),
    do: {:noreply, record(%{assigns | tree_expanded: not assigns.tree_expanded}, "toggled lib")}

  def handle_event("line_selected", %{value: value}, assigns),
    do: {:noreply, record(%{assigns | line_selected: value}, "selected #{value}")}

  defp story_navigation(stories, active) do
    stories
    |> Enum.group_by(& &1.group)
    |> Enum.sort_by(fn {group, _} -> group_order(group) end)
    |> Enum.flat_map(fn {group, entries} ->
      [group_label(group) | Enum.map(entries, &story_button(&1, active))]
    end)
  end

  defp group_label(group) do
    assigns = %{group: group}

    ~GPUI"""
    <text class="px-2 pt-3 pb-1 text-sm font-semibold text-slate-500">{assigns.group}</text>
    """
  end

  defp story_button(story, active) do
    assigns = %{story: story, active: story.id == active}

    ~GPUI"""
    <UI.button id={"story-" <> assigns.story.id} label={assigns.story.title} variant={if(assigns.active, do: "secondary", else: "ghost")} phx-click={"story-" <> assigns.story.id} />
    """
  end

  defp story("welcome", _assigns) do
    ~GPUI"""
    <div class="flex grow items-center justify-center">
      <div class="flex flex-col w-[560px] gap-5">
        <text class="text-3xl font-semibold text-slate-900">Native UI, ordinary Elixir</text>
        <text class="text-lg text-slate-600">Choose one component from the sidebar. Every value is controlled by the view process; the native host owns only interaction mechanics.</text>
        <div class="flex gap-3 border-t border-slate-200 pt-5">
          <text class="text-sm text-slate-500">GPUI.Application</text><text class="text-sm text-slate-400">→</text>
          <text class="text-sm text-slate-500">GPUI.View</text><text class="text-sm text-slate-400">→</text>
          <text class="text-sm text-slate-500">GPUI Snapshot</text>
        </div>
      </div>
    </div>
    """
  end

  defp story("button", _assigns), do: canvas("Button variants", button_examples())
  defp story("progress", _assigns), do: canvas("Deployment", progress_example())
  defp story("input", assigns), do: canvas("Profile", input_example(assigns))
  defp story("select", assigns), do: canvas("Runtime", select_example(assigns))
  defp story("checkbox", assigns), do: canvas("Reports", checkbox_example(assigns))
  defp story("switch", assigns), do: canvas("Notifications", switch_example(assigns))
  defp story("radio", assigns), do: canvas("Plan", radio_example(assigns))
  defp story("slider", assigns), do: canvas("Volume", slider_example(assigns))
  defp story("popover", assigns), do: canvas("Popover", popover_example(assigns))
  defp story("tooltip", _assigns), do: canvas("Tooltip", tooltip_example())
  defp story("dialog", assigns), do: canvas("Dialog", dialog_example(assigns))
  defp story("menu", assigns), do: canvas("Dropdown menu", menu_example(assigns))
  defp story("tabs", assigns), do: canvas("Tabs", tabs_example(assigns))
  defp story("accordion", assigns), do: canvas("Accordion", accordion_example(assigns))

  defp story("virtual_list", assigns),
    do: collection_canvas("Virtual list", virtual_list(assigns), "w-[420px]")

  defp story("data_table", assigns),
    do: collection_canvas("Services", data_table(assigns), "w-[680px]")

  defp story("tree", assigns), do: collection_canvas("Project files", tree(assigns), "w-[420px]")

  defp story("code_viewer", assigns),
    do: collection_canvas("lib/gpui/runtime.ex", code_viewer(assigns), "w-[760px]")

  defp canvas(title, child) do
    assigns = %{title: title, child: child}

    ~GPUI"""
    <div class="flex grow items-start justify-center pt-10">
      <div class="flex flex-col w-[620px] gap-5">
        <text class="text-sm font-semibold text-slate-500">{assigns.title}</text>
        <div class="flex flex-col gap-4 border border-slate-200 rounded-lg p-6 bg-white">{assigns.child}</div>
      </div>
    </div>
    """
  end

  defp collection_canvas(title, child, width) do
    assigns = %{title: title, child: child, width: width}

    ~GPUI"""
    <div class="flex grow items-start justify-center pt-4">
      <div class={"flex flex-col h-[580px] gap-3 " <> assigns.width}>
        <text class="text-sm font-semibold text-slate-500">{assigns.title}</text>
        <div class="flex grow min-h-0 border border-slate-200 rounded-lg p-3 bg-white">{assigns.child}</div>
      </div>
    </div>
    """
  end

  defp button_examples do
    ~GPUI"""
    <div class="flex flex-wrap items-center gap-3">
      <UI.button id="button-default" label="Default" phx-click="noop" />
      <UI.button id="button-primary" label="Primary" variant="primary" phx-click="noop" />
      <UI.button id="button-danger" label="Delete" variant="danger" phx-click="noop" />
      <UI.button id="button-loading" label="Saving" loading={true} />
      <UI.button id="button-disabled" label="Disabled" disabled={true} />
    </div>
    """
  end

  defp progress_example do
    ~GPUI"""
    <div class="flex flex-col gap-3"><div class="flex justify-between"><text>Release archive</text><text class="text-slate-500">72%</text></div><UI.progress id="gallery-progress" label="Deployment progress" value={72} max={100} /></div>
    """
  end

  defp input_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <UI.input id="gallery-name" label="Display name" value={assigns.assigns.name} cleanable={true} phx-change="name_changed" />
    """
  end

  defp select_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-col gap-4"><UI.select id="gallery-language" label="Language" value={assigns.assigns.language} options={[{"Elixir", "elixir"}, {"Rust", "rust"}]} phx-change="language_changed" /><UI.combobox id="gallery-framework" label="Framework" value={assigns.assigns.framework} options={["Phoenix", "LiveView", "Ash"]} phx-change="framework_changed" /></div>
    """
  end

  defp checkbox_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <UI.checkbox id="gallery-checkbox" label="Email weekly reports" checked={assigns.assigns.reports} phx-change="reports_changed" />
    """
  end

  defp switch_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <UI.switch id="gallery-switch" label="Desktop notifications" checked={assigns.assigns.notifications} phx-change="notifications_changed" />
    """
  end

  defp radio_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <UI.radio_group id="gallery-plan" label="Plan" value={assigns.assigns.plan} options={[{"Free", "free"}, {"Team", "team"}, %{label: "Enterprise", value: "enterprise", disabled: true}]} orientation="horizontal" phx-change="plan_changed" />
    """
  end

  defp slider_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-col gap-3"><text>Notification volume: {round(assigns.assigns.volume)}%</text><UI.slider id="gallery-volume" label="Notification volume" value={assigns.assigns.volume} min={0} max={100} step={5} phx-change="volume_changed" /></div>
    """
  end

  defp popover_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <Overlay.popover id="gallery-popover" label="Runtime process" open={assigns.assigns.overlay == "popover"} phx-change="overlay_changed"><:trigger><UI.button id="show-popover" label="Inspect process" phx-click="show-popover" /></:trigger><:content><div class="flex flex-col gap-1 p-2"><text class="font-semibold">Examples.ComponentGallery.View</text><text class="text-slate-500">Authoritative state: Elixir process</text></div></:content></Overlay.popover>
    """
  end

  defp tooltip_example do
    ~GPUI"""
    <Overlay.tooltip id="gallery-tooltip" delay={100}><:trigger><UI.button id="tooltip-trigger" label="Hover for details" /></:trigger><:content>Rendered by the native GPUI host</:content></Overlay.tooltip>
    """
  end

  defp dialog_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div><UI.button id="show-dialog" label="Open dialog" variant="primary" phx-click="show-dialog" /><Overlay.dialog id="gallery-dialog" open={assigns.assigns.overlay == "dialog"} title="Create workspace" width={420} phx-change="overlay_changed"><:content><div class="flex flex-col gap-3 p-2"><UI.input id="dialog-name" label="Workspace name" value="Observatory" phx-change="noop" /><UI.button id="dialog-create" label="Create workspace" variant="primary" phx-click="noop" /></div></:content></Overlay.dialog></div>
    """
  end

  defp menu_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex items-center gap-4"><Overlay.dropdown_menu id="gallery-menu" label="Workspace actions" open={assigns.assigns.overlay == "menu"} phx-change="overlay_changed" phx-select="menu_selected"><:trigger><UI.button id="show-menu" label="Actions" phx-click="show-menu" /></:trigger><:item value="duplicate">Duplicate</:item><:item value="pin" checked={true}>Pinned</:item><:item value="archive">Archive</:item><:item value="delete" disabled={true}>Delete permanently</:item></Overlay.dropdown_menu><text class="text-sm text-slate-500">{assigns.assigns.menu_result || "No command selected"}</text></div>
    """
  end

  defp tabs_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <div class="flex flex-col gap-5"><UI.tabs id="gallery-tabs" value={assigns.assigns.tab} options={[{"Overview", "overview"}, {"Activity", "activity"}, {"Settings", "settings"}]} variant="underline" phx-change="tabs_changed" /><text class="text-slate-600">Selected section: {assigns.assigns.tab}</text></div>
    """
  end

  defp accordion_example(assigns) do
    assigns = %{assigns: assigns}

    ~GPUI"""
    <UI.accordion id="gallery-accordion" expanded={assigns.assigns.expanded} multiple={true} phx-change="accordion_changed"><UI.accordion_item id="account" title="Account"><text>Identity, sessions, and connected devices.</text></UI.accordion_item><UI.accordion_item id="billing" title="Billing"><text>Invoices and usage thresholds.</text></UI.accordion_item><UI.accordion_item id="security" title="Security"><text>Passkeys and recovery settings.</text></UI.accordion_item></UI.accordion>
    """
  end

  defp virtual_list(assigns) do
    items =
      Enum.map(1..100, fn number ->
        UI.virtual_list_item(%{
          id: "item-#{number}",
          children: ["Build artifact #{String.pad_leading(to_string(number), 3, "0")}"]
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
      UI.table_column(%{id: "service", label: "Service", width: 180, sortable: true}),
      UI.table_column(%{id: "status", label: "Status", width: 140}),
      UI.table_column(%{
        id: "latency",
        label: "Latency",
        width: 120,
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
  defp group_order("Getting started"), do: 0
  defp group_order("Components"), do: 1
  defp group_order("Overlays"), do: 2
  defp group_order("Navigation"), do: 3
  defp group_order("Collections"), do: 4

  defp record(assigns, event),
    do: %{assigns | event_count: assigns.event_count + 1, last_event: event}

  defp reset_story(assigns) do
    Map.merge(assigns, %{
      overlay: nil,
      menu_result: nil,
      name: "Ada Lovelace",
      language: "elixir",
      framework: "Phoenix",
      reports: true,
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
    story = args |> Map.new() |> Map.get(:story, "welcome")

    assigns = %{
      story: story,
      query: "",
      event_count: 0,
      last_event: nil,
      overlay: nil,
      menu_result: nil,
      name: "Ada Lovelace",
      language: "elixir",
      framework: "Phoenix",
      reports: true,
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
         size(1180, 760)
         root(Examples.ComponentGallery.View, assigns)
       end
     ]}
  end
end
