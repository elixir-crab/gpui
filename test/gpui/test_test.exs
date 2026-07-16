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
  end

  defmodule TestApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "Primary" do
           root(TestView, count: 0, name: "", language: "rust")
         end
       ]}
    end
  end

  test "renders and queries view trees directly" do
    tree = render(TestView, count: 2, name: "Ada", language: "rust")

    assert %GPUI.Element{type: :ui_button} = find!(tree, id: "increment")
    assert %GPUI.Element{type: :ui_input} = find!(tree, type: :ui_input)
    assert 1 = tree |> all(type: :text) |> length()
  end

  test "starts deterministic runtimes and dispatches user events" do
    runtime = start_gpui!(TestApp)

    assert %{count: 0, name: "", language: "rust"} = assigns(runtime)
    assert %{title: "Primary"} = window_snapshot(runtime, "Primary")
    assert %{type: :ui_input} = runtime |> tree() |> find!(id: "name")

    click(runtime, "increment")
    assert %{count: 1} = assigns(runtime)

    change(runtime, "name_changed", "Ada")
    select(runtime, "language_changed", "elixir")
    assert %{count: 1, name: "Ada", language: "elixir"} = assigns(runtime)

    select(runtime, "language_changed", nil)
    assert %{language: nil} = assigns(runtime)
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
