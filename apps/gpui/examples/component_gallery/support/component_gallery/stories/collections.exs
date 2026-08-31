defmodule Examples.ComponentGallery.Stories.VirtualList do
  @behaviour Examples.ComponentGallery.Story
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "virtual_list",
      group: "Collections",
      title: "Virtual list",
      description: "Stable selection over a larger item set."
    }

  @impl true
  def initial_state, do: %{selected: nil}

  @impl true
  def render_story(state) do
    items =
      Enum.map(1..100, fn number ->
        UI.virtual_list_item(%{
          id: "item-#{number}",
          children: ["Build artifact #{String.pad_leading(to_string(number), 3, "0")}"]
        })
      end)

    list =
      UI.virtual_list(%{
        id: "gallery-list",
        label: "Build artifacts",
        selected: state.selected,
        reveal: state.selected,
        item_height: 42,
        "phx-change": "story:virtual_list:selected",
        class: "grow",
        children: items
      })

    Components.collection_canvas("Virtual list", list, "w-[420px]")
  end

  @impl true
  def story_event("selected", %{value: value}, state), do: {:noreply, %{state | selected: value}}
end

defmodule Examples.ComponentGallery.Stories.DataTable do
  @behaviour Examples.ComponentGallery.Story
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "data_table",
      group: "Collections",
      title: "Data table",
      description: "Sortable columns and controlled row selection."
    }

  @impl true
  def initial_state, do: %{selected: nil, sort: "service"}

  @impl true
  def render_story(state) do
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

    table =
      UI.data_table(%{
        id: "gallery-table",
        label: "Services",
        selected: state.selected,
        reveal: state.selected,
        sort_column: state.sort,
        sort_direction: "ascending",
        item_height: 48,
        "phx-change": "story:data_table:selected",
        "phx-sort": "story:data_table:sorted",
        class: "grow",
        children: columns ++ rows
      })

    Components.collection_canvas("Services", table, "w-[680px]")
  end

  @impl true
  def story_event("selected", %{value: value}, state), do: {:noreply, %{state | selected: value}}
  @impl true
  def story_event("sorted", %{value: value}, state), do: {:noreply, %{state | sort: value}}
end

defmodule Examples.ComponentGallery.Stories.Tree do
  @behaviour Examples.ComponentGallery.Story
  alias Examples.ComponentGallery.Components
  alias GPUI.UI

  @impl true
  def metadata,
    do: %{
      id: "tree",
      group: "Collections",
      title: "Tree",
      description: "Hierarchical navigation with controlled expansion."
    }

  @impl true
  def initial_state, do: %{selected: nil, expanded: true}

  @impl true
  def render_story(state) do
    items = [
      UI.tree_item(%{
        id: "lib",
        level: 1,
        branch: true,
        expanded: state.expanded,
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

    tree =
      UI.tree(%{
        id: "gallery-tree",
        label: "Project files",
        selected: state.selected,
        reveal: state.selected,
        item_height: 42,
        "phx-change": "story:tree:selected",
        "phx-toggle": "story:tree:toggled",
        class: "grow",
        children: items
      })

    Components.collection_canvas("Project files", tree, "w-[420px]")
  end

  @impl true
  def story_event("selected", %{value: value}, state), do: {:noreply, %{state | selected: value}}

  @impl true
  def story_event("toggled", %{value: "lib"}, state),
    do: {:noreply, %{state | expanded: not state.expanded}}
end
