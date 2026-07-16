defmodule GPUI.TestTest do
  use GPUI.Test, async: true

  defmodule TestView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div id="root">
        <text>Count: {assigns.count}</text>
        <GPUI.UI.button id="increment" label="Increment" phx-click="increment" />
        <GPUI.UI.input id="name" value={assigns.name} phx-change="name_changed" />
        <GPUI.UI.select
          id="language"
          value={assigns.language}
          options={[{"Rust", "rust"}, {"Elixir", "elixir"}]}
          phx-change="language_changed"
        />
        <GPUI.UI.combobox
          id="framework"
          value={assigns.framework}
          options={["Phoenix", "LiveView"]}
          phx-change="framework_changed"
          phx-search="framework_searched"
        />
        <GPUI.UI.switch
          id="notifications"
          checked={assigns.notifications}
          phx-change="notifications_changed"
        />
        <GPUI.UI.radio_group
          id="plan"
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
          value={assigns.volume}
          phx-change="volume_changed"
          phx-release="volume_released"
        />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("name_changed", %{value: name}, assigns),
      do: {:noreply, %{assigns | name: name}}

    def handle_event("language_changed", %{value: language}, assigns),
      do: {:noreply, %{assigns | language: language}}

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
  end

  defmodule TestApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Primary" do
           root(TestView,
             count: 0,
             name: "",
             language: "rust",
             framework: nil,
             query: "",
             notifications: false,
             plan: "free",
             expanded: [],
             section: "general",
             volume: 25.0,
             released_volume: nil
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
        language: "rust",
        framework: nil,
        query: "",
        notifications: false,
        plan: "free",
        expanded: [],
        section: "general",
        volume: 25.0,
        released_volume: nil
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
             language: "rust",
             framework: nil,
             query: "",
             notifications: false,
             plan: "free",
             expanded: [],
             section: "general",
             volume: 25.0,
             released_volume: nil
           } = assigns(runtime)

    assert %{title: "Primary"} = window_snapshot(runtime, "Primary")
    assert %{type: :ui_input} = runtime |> tree() |> find!(id: "name")

    click(runtime, "increment")
    assert %{count: 1} = assigns(runtime)

    change(runtime, "name_changed", "Ada")
    select(runtime, "language_changed", "elixir")
    assert %{count: 1, name: "Ada", language: "elixir"} = assigns(runtime)

    select(runtime, "language_changed", nil)
    search(runtime, "framework_searched", "live")
    select(runtime, "framework_changed", "LiveView")
    toggle(runtime, "notifications_changed", true)
    select(runtime, "plan_changed", "pro")
    expand(runtime, "details_changed", ["security"])
    select(runtime, "section_changed", "advanced")
    slide(runtime, "volume_changed", 40.0)
    release(runtime, "volume_released", 40.0)

    assert %{
             language: nil,
             query: "live",
             framework: "LiveView",
             notifications: true,
             plan: "pro",
             expanded: ["security"],
             section: "advanced",
             volume: 40.0,
             released_volume: 40.0
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
