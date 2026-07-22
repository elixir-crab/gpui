defmodule GPUI.TestTest do
  use GPUI.Test, async: true

  defmodule TestView do
    use GPUI.View

    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div id="root">
        <text>Count: {assigns.count}</text>
        <GPUI.UI.button id="increment" label="Increment" phx-click="increment" />
        <GPUI.UI.input
          id="name"
          label="Name"
          value={assigns.name}
          phx-change="name_changed"
          phx-submit="name_submitted"
        />
        <GPUI.UI.file_picker
          id="file"
          label="Choose file"
          phx-change="file_selected"
        />
        <GPUI.UI.select
          id="language"
          label="Language"
          value={assigns.language}
          options={[{"Rust", "rust"}, {"Elixir", "elixir"}]}
          phx-change="language_changed"
        />
        <GPUI.UI.combobox
          id="framework"
          label="Framework"
          value={assigns.framework}
          options={["Phoenix", "LiveView"]}
          phx-change="framework_changed"
          phx-search="framework_searched"
        />
        <GPUI.UI.switch
          id="notifications"
          label="Notifications"
          checked={assigns.notifications}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="plan"
          label="Plan"
          value={assigns.plan}
          options={[{"Free", "free"}, {"Pro", "pro"}]}
          phx-change="plan_changed"
        />
        <GPUI.UI.accordion
          id="details"
          expanded={assigns.expanded}
          multiple={true}
          phx-change="details_changed"
        >
          <GPUI.UI.accordion_item id="account" title="Account" />
          <GPUI.UI.accordion_item id="security" title="Security" />
        </GPUI.UI.accordion>
        <GPUI.UI.tabs
          id="section"
          value={assigns.section}
          options={[{"General", "general"}, {"Advanced", "advanced"}]}
          phx-change="section_changed"
        />
        <GPUI.UI.slider
          id="volume"
          label="Volume"
          value={assigns.volume}
          phx-change="volume_changed"
          phx-release="volume_released"
        />
        <Overlay.popover
          id="account-menu"
          label="Account"
          open={assigns.overlay_open}
          phx-change="overlay_changed"
        >
          <:trigger>Account</:trigger>
          <:content>Profile</:content>
        </Overlay.popover>
        <Overlay.dropdown_menu
          id="file-menu"
          label="File menu"
          open={assigns.menu_open}
          phx-change="menu_open_changed"
          phx-select="menu_selected"
        >
          <:trigger>File</:trigger>
          <:item value="new">New</:item>
          <:item value="open">Open</:item>
        </Overlay.dropdown_menu>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("name_changed", %{value: name}, assigns),
      do: {:noreply, %{assigns | name: name}}

    def handle_event("name_submitted", %{value: name}, assigns),
      do: {:noreply, %{assigns | submitted_name: name}}

    def handle_event("file_selected", %{value: file}, assigns),
      do: {:noreply, %{assigns | file: file}}

    def handle_event("records_range", %{value: range}, assigns),
      do: {:noreply, %{assigns | range: range}}

    def handle_event("language_changed", %{value: language}, assigns),
      do: {:noreply, %{assigns | language: language}}

    def handle_event("tree_toggled", %{value: id}, assigns),
      do: {:noreply, %{assigns | tree_branch: id}}

    def handle_event("framework_changed", %{value: framework}, assigns),
      do: {:noreply, %{assigns | framework: framework}}

    def handle_event("framework_searched", %{value: query}, assigns),
      do: {:noreply, %{assigns | query: query}}

    def handle_event("notifications_changed", %{value: notifications}, assigns),
      do: {:noreply, %{assigns | notifications: notifications}}

    def handle_event("plan_changed", %{value: plan}, assigns),
      do: {:noreply, %{assigns | plan: plan}}

    def handle_event("details_changed", %{value: expanded}, assigns),
      do: {:noreply, %{assigns | expanded: expanded}}

    def handle_event("section_changed", %{value: section}, assigns),
      do: {:noreply, %{assigns | section: section}}

    def handle_event("volume_changed", %{value: volume}, assigns),
      do: {:noreply, %{assigns | volume: volume}}

    def handle_event("volume_released", %{value: volume}, assigns),
      do: {:noreply, %{assigns | released_volume: volume}}

    def handle_event("overlay_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | overlay_open: open}}

    def handle_event("menu_open_changed", %{value: open}, assigns),
      do: {:noreply, %{assigns | menu_open: open}}

    def handle_event("menu_selected", %{value: value}, assigns),
      do: {:noreply, %{assigns | menu_selection: value}}

    @impl GPUI.View
    def handle_info(:increment, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}
  end

  defmodule TestApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Primary" do
           shortcut("increment", "primary-i")

           root(TestView,
             count: 0,
             name: "",
             submitted_name: nil,
             file: nil,
             range: nil,
             language: "rust",
             framework: nil,
             query: "",
             notifications: false,
             plan: "free",
             expanded: [],
             section: "general",
             volume: 25.0,
             released_volume: nil,
             overlay_open: false,
             menu_open: false,
             menu_selection: nil,
             tree_branch: nil
           )
         end
       ]}
    end
  end

  test "renders and queries view trees directly" do
    tree =
      render(TestView,
        count: 2,
        name: "Ada",
        submitted_name: nil,
        file: nil,
        range: nil,
        language: "rust",
        framework: nil,
        query: "",
        notifications: false,
        plan: "free",
        expanded: [],
        section: "general",
        volume: 25.0,
        released_volume: nil,
        overlay_open: false,
        menu_open: false,
        menu_selection: nil,
        tree_branch: nil
      )

    assert %GPUI.Element{type: :ui_button} = find!(tree, id: "increment")
    assert %GPUI.Element{type: :ui_input} = find!(tree, type: :ui_input)
    assert 1 = tree |> all(type: :text) |> length()
  end

  test "starts deterministic runtimes and dispatches user events" do
    runtime = start_gpui!(TestApp)

    assert %{
             count: 0,
             name: "",
             submitted_name: nil,
             range: nil,
             language: "rust",
             framework: nil,
             query: "",
             notifications: false,
             plan: "free",
             expanded: [],
             section: "general",
             volume: 25.0,
             released_volume: nil,
             overlay_open: false,
             menu_open: false,
             menu_selection: nil,
             tree_branch: nil
           } = assigns(runtime)

    assert %{title: "Primary"} = window_snapshot(runtime, "Primary")
    assert %{type: :ui_input} = runtime |> tree() |> find!(id: "name")

    click(runtime, "increment")
    command(runtime, "increment")
    send_view(runtime, :increment)
    assert %{count: 3} = assigns(runtime)

    change(runtime, "name_changed", "Ada")
    submit(runtime, "name_submitted", "Ada")
    assert %{submitted_name: "Ada"} = assigns(runtime)
    file_select(runtime, "file_selected", "fixture.bin", <<1, 2, 3>>)

    assert %{file: %{status: :selected, name: "fixture.bin", size: 3, data: <<1, 2, 3>>}} =
             assigns(runtime)

    file_cancel(runtime, "file_selected")
    assert %{file: %{status: :cancelled}} = assigns(runtime)

    range(runtime, "records_range", 120, 160)
    assert %{range: %{first: 120, last: 160}} = assigns(runtime)

    tree_toggle(runtime, "tree_toggled", "dir:lib")
    assert %{tree_branch: "dir:lib"} = assigns(runtime)

    select(runtime, "language_changed", "elixir")
    assert %{count: 3, name: "Ada", language: "elixir"} = assigns(runtime)

    select(runtime, "language_changed", nil)
    search(runtime, "framework_searched", "live")
    select(runtime, "framework_changed", "LiveView")
    toggle(runtime, "notifications_changed", true)
    select(runtime, "plan_changed", "pro")
    expand(runtime, "details_changed", ["security"])
    select(runtime, "section_changed", "advanced")
    slide(runtime, "volume_changed", 40.0)
    release(runtime, "volume_released", 40.0)
    open(runtime, "overlay_changed", true)
    open(runtime, "menu_open_changed", true)
    menu_select(runtime, "menu_selected", "open")

    assert %{
             language: nil,
             query: "live",
             framework: "LiveView",
             notifications: true,
             plan: "pro",
             expanded: ["security"],
             section: "advanced",
             volume: 40.0,
             released_volume: 40.0,
             overlay_open: true,
             menu_open: true,
             menu_selection: "open"
           } = assigns(runtime)
  end

  test "public test display records snapshots chronologically" do
    display = start_supervised!({GPUI.Test.Display, []})
    first = %GPUI.Snapshot{windows: [], resources: %{}}
    second = %GPUI.Snapshot{windows: [%{id: 1}], resources: %{}}

    assert :ok = GPUI.Test.Display.sync(display, first)
    assert :ok = GPUI.Test.Display.sync(display, second)
    assert [^first, ^second] = GPUI.Test.Display.snapshots(display)
    assert ^second = GPUI.Test.Display.latest_snapshot(display)
  end
end
