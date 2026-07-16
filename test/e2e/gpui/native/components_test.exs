defmodule GPUI.Native.ComponentsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule ComponentsView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[420px] p-4 gap-4 bg-slate-900">
        <GPUI.UI.button
          id="component-button"
          label="Increment"
          variant="primary"
          phx-click="increment"
        />
        <GPUI.UI.checkbox
          id="component-checkbox"
          label="Enabled"
          checked={assigns.enabled}
          phx-change="toggle"
        />
        <GPUI.UI.input
          id="component-input"
          value={assigns.name}
          placeholder="Name"
          cleanable={true}
          phx-change="name_changed"
        />
        <GPUI.UI.select
          id="component-language"
          value={assigns.language}
          options={[{"Rust", "rust"}, {"Elixir", "elixir"}, {"Zig", "zig"}]}
          phx-change="language_changed"
        />
        <GPUI.UI.combobox
          id="component-framework"
          value={assigns.framework}
          options={assigns.framework_options}
          search_placeholder="Search frameworks"
          cleanable={true}
          loading={assigns.framework_loading}
          phx-change="framework_changed"
          phx-search="framework_searched"
        />
        <text class="text-white">Count: {assigns.count}; Enabled: {assigns.enabled}; Name: {assigns.name}; Language: {assigns.language}; Framework: {assigns.framework}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("increment", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("toggle", %{value: enabled}, assigns) when is_boolean(enabled),
      do: {:noreply, %{assigns | enabled: enabled}}

    def handle_event("name_changed", %{value: name}, assigns) when is_binary(name),
      do: {:noreply, %{assigns | name: name}}

    def handle_event("replace_name", _event, assigns),
      do: {:noreply, %{assigns | name: "server"}}

    def handle_event("clear_name", _event, assigns),
      do: {:noreply, %{assigns | name: ""}}

    def handle_event("language_changed", %{value: language}, assigns),
      do: {:noreply, %{assigns | language: language}}

    def handle_event("framework_changed", %{value: framework}, assigns),
      do: {:noreply, %{assigns | framework: framework, framework_loading: true}}

    def handle_event("framework_searched", %{value: query}, assigns) do
      options = Enum.filter(["Phoenix", "LiveView", "Surface"], &contains?(&1, query))
      {:noreply, %{assigns | framework_query: query, framework_options: options}}
    end

    defp contains?(label, query),
      do: String.contains?(String.downcase(label), String.downcase(query))
  end

  defmodule ComponentsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 420)

           root(ComponentsView,
             count: 0,
             enabled: false,
             name: "",
             language: "rust",
             framework: nil,
             framework_query: "",
             framework_options: ["Phoenix", "LiveView", "Surface"],
             framework_loading: false
           )
         end
       ]}
    end
  end

  defmodule SliderView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[360px] h-[100px] p-4 bg-slate-900">
        <GPUI.UI.slider
          id="component-volume"
          class="w-full h-full"
          value={assigns.volume}
          min={assigns.min}
          max={assigns.max}
          step={assigns.step}
          scale={assigns.scale}
          disabled={assigns.disabled}
          phx-change="volume_changed"
          phx-release="volume_released"
        />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("volume_changed", %{value: volume}, assigns),
      do: {:noreply, %{assigns | volume: volume}}

    def handle_event("volume_released", %{value: volume}, assigns) do
      {:noreply,
       %{
         assigns
         | released_volume: volume,
           min: 10.0,
           max: 1000.0,
           step: 10.0,
           scale: "logarithmic"
       }}
    end

    def handle_event("disable_slider", _event, assigns),
      do: {:noreply, %{assigns | disabled: true}}
  end

  defmodule SliderApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 100)

           root(SliderView,
             volume: 25.0,
             released_volume: nil,
             min: 0.0,
             max: 100.0,
             step: 5.0,
             scale: "linear",
             disabled: false
           )
         end
       ]}
    end
  end

  defmodule AccordionView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[360px] h-[160px] p-4 bg-slate-900">
        <GPUI.UI.accordion
          id="component-accordion"
          expanded={assigns.expanded}
          multiple={true}
          disabled={assigns.disabled}
          phx-change="details_changed"
        >
          <GPUI.UI.accordion_item id="account" title="Account">
            <GPUI.UI.button id="nested-action" label="Nested action" phx-click="nested_click" />
          </GPUI.UI.accordion_item>
          <GPUI.UI.accordion_item id="security" title="Security">
            <text>Security details</text>
          </GPUI.UI.accordion_item>
        </GPUI.UI.accordion>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("details_changed", %{value: expanded}, assigns),
      do: {:noreply, %{assigns | expanded: expanded}}

    def handle_event("nested_click", _event, assigns),
      do: {:noreply, %{assigns | nested_clicks: assigns.nested_clicks + 1}}

    def handle_event("disable_accordion", _event, assigns),
      do: {:noreply, %{assigns | disabled: true}}
  end

  defmodule AccordionApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 160)
           root(AccordionView, expanded: ["account"], nested_clicks: 0, disabled: false)
         end
       ]}
    end
  end

  defmodule TabsView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[360px] h-[80px] p-4 bg-slate-900">
        <GPUI.UI.tabs
          id="component-tabs"
          value={assigns.section}
          options={[{"General", "general"}, {"Advanced", "advanced"}]}
          variant="segmented"
          disabled={assigns.disabled}
          phx-change="section_changed"
        />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("section_changed", %{value: section}, assigns),
      do: {:noreply, %{assigns | section: section, disabled: true}}
  end

  defmodule TabsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 80)
           root(TabsView, section: "general", disabled: false)
         end
       ]}
    end
  end

  test "native GPUI components emit controlled Elixir events and rerender" do
    title = "GPUI Components E2E #{System.unique_integer([:positive])}"

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: ComponentsApp,
        args: %{title: title},
        display_opts: [theme: :dark]
      )

    {:ok, theme_display} = GPUI.Display.Native.start_link([])
    on_exit(fn -> Desktop.stop_process(theme_display) end)
    on_exit(fn -> Desktop.stop_process(runtime) end)

    assert :ok = GPUI.Display.Native.set_theme(theme_display, :light)
    assert :ok = GPUI.Display.Native.set_theme(theme_display, :dark)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 80, 32)

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: false} = assigns(runtime)
    end)

    Desktop.click!(window_id, 32, 72)

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: true} = assigns(runtime)
    end)

    Desktop.click!(window_id, 32, 72)

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: false} = assigns(runtime)
    end)

    Desktop.click!(window_id, 80, 112)
    Desktop.type!(window_id, "abc")

    Desktop.eventually(fn ->
      assert %{count: 1, enabled: false, name: "abc"} = assigns(runtime)
    end)

    %{windows: [window]} = GPUI.Runtime.snapshot(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: window.id,
      event: "replace_name"
    })

    Desktop.eventually(fn ->
      assert %{name: "server"} = assigns(runtime)
    end)

    Desktop.key!(window_id, "End")
    Desktop.type!(window_id, "!")

    Desktop.eventually(fn ->
      assert %{name: "server!"} = assigns(runtime)
    end)

    Desktop.key!(window_id, "ctrl+a")
    Desktop.key!(window_id, "ctrl+c")

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: window.id,
      event: "clear_name"
    })

    Desktop.eventually(fn ->
      assert %{name: ""} = assigns(runtime)
    end)

    Desktop.key!(window_id, "ctrl+v")

    Desktop.eventually(fn ->
      assert %{name: "server!"} = assigns(runtime)
    end)

    Desktop.click!(window_id, 80, 160)
    Desktop.click!(window_id, 80, 230)

    Desktop.eventually(fn ->
      assert %{language: "elixir"} = assigns(runtime)
    end)

    Desktop.key!(window_id, "Tab")
    Desktop.key!(window_id, "Return")
    Desktop.type!(window_id, "live")

    Desktop.eventually(fn ->
      assert %{framework_query: "live"} = assigns(runtime)
    end)

    Desktop.key!(window_id, "Escape")
    Process.sleep(100)
    assert %{framework: nil} = assigns(runtime)

    Desktop.key!(window_id, "Return")
    Desktop.key!(window_id, "Down")
    Desktop.key!(window_id, "Return")

    Desktop.eventually(fn ->
      assert %{framework: "LiveView", framework_loading: true} = assigns(runtime)
    end)

    Desktop.key!(window_id, "Return")
    Desktop.type!(window_id, "x")
    Process.sleep(100)
    assert %{framework_query: "live"} = assigns(runtime)
  end

  test "native accordion emits controlled expanded IDs and respects disabled state" do
    title = "GPUI Accordion E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: AccordionApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 100, 68)

    Desktop.eventually(fn ->
      assert %{expanded: ["account"], nested_clicks: 1} = assigns(runtime)
    end)

    Desktop.click!(window_id, 100, 140)

    Desktop.eventually(fn ->
      assert %{expanded: ["account", "security"]} = assigns(runtime)
    end)

    %{windows: [window]} = GPUI.Runtime.snapshot(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: window.id,
      event: "disable_accordion"
    })

    Desktop.eventually(fn -> assert %{disabled: true} = assigns(runtime) end)
    Process.sleep(200)
    Desktop.click!(window_id, 100, 32)
    Process.sleep(100)
    assert %{expanded: ["account", "security"]} = assigns(runtime)
  end

  test "native tabs emit controlled selections and respect disabled state" do
    title = "GPUI Tabs E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: TabsApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 130, 32)

    Desktop.eventually(fn ->
      assert %{section: "advanced", disabled: true} = assigns(runtime)
    end)

    Desktop.click!(window_id, 80, 32)
    Process.sleep(100)
    assert %{section: "advanced"} = assigns(runtime)
  end

  test "native slider emits change and release events and respects disabled state" do
    title = "GPUI Slider E2E #{System.unique_integer([:positive])}"
    {:ok, runtime} = GPUI.Runtime.start_link(app: SliderApp, args: %{title: title})
    on_exit(fn -> Desktop.stop_process(runtime) end)

    window_id = Desktop.window_id!(title)
    Desktop.click!(window_id, 278, 20)

    Desktop.eventually(fn ->
      assert %{
               volume: 80.0,
               released_volume: 80.0,
               min: 10.0,
               max: 1000.0,
               step: 10.0,
               scale: "logarithmic"
             } = assigns(runtime)
    end)

    Desktop.click!(window_id, 180, 20)

    Desktop.eventually(fn ->
      assert %{volume: 100.0, released_volume: 100.0} = assigns(runtime)
    end)

    %{windows: [window]} = GPUI.Runtime.snapshot(runtime)

    GPUI.Runtime.dispatch_event(runtime, %{
      type: :click,
      window_id: window.id,
      event: "disable_slider"
    })

    Desktop.eventually(fn -> assert %{disabled: true} = assigns(runtime) end)
    Process.sleep(200)
    Desktop.click!(window_id, 278, 20)
    Process.sleep(100)
    assert %{volume: 100.0, released_volume: 100.0} = assigns(runtime)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
