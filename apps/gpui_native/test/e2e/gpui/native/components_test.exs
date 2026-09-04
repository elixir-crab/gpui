defmodule GPUI.Native.ComponentsE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  setup context do
    Desktop.setup(context, [])
  end

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
          label="Name"
          value={assigns.name}
          focus_request={assigns.name_focus_request}
          placeholder="Name"
          cleanable={true}
          phx-change="name_changed"
          phx-submit="name_submitted"
        />
        <GPUI.UI.select
          id="component-language"
          label="Language"
          value={assigns.language}
          options={[{"Rust", "rust"}, {"Elixir", "elixir"}, {"Zig", "zig"}]}
          phx-change="language_changed"
        />
        <GPUI.UI.combobox
          id="component-framework"
          label="Framework"
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

    def handle_event("name_submitted", %{value: name}, assigns) when is_binary(name),
      do: {:noreply, %{assigns | submitted_name: name}}

    def handle_event("focus_name", _event, assigns),
      do: {:noreply, %{assigns | name_focus_request: assigns.name_focus_request + 1}}

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
             submitted_name: nil,
             name_focus_request: 0,
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

  test "desktop renders native input controls", %{desktop: desktop} do
    title = "GPUI Input Submission E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: ComponentsApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{name: "", submitted_name: nil} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  defmodule SliderView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="w-[360px] h-[100px] p-4 bg-slate-900">
        <GPUI.UI.slider
          id="component-volume"
          label="Volume"
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
      do: {:noreply, %{assigns | section: section, selections: assigns.selections + 1}}

    def handle_event("disable_tabs", _event, assigns),
      do: {:noreply, %{assigns | disabled: true}}
  end

  defmodule TabsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 80)
           root(TabsView, section: "general", disabled: false, selections: 0)
         end
       ]}
    end
  end

  test "desktop renders the native component gallery", %{desktop: desktop} do
    title = "GPUI Components E2E #{System.unique_integer([:positive])}"

    runtime =
      start_runtime!(desktop,
        app: ComponentsApp,
        args: %{title: title},
        display_opts: [theme: :dark]
      )

    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{count: 0, enabled: false} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  test "desktop renders a native accordion", %{desktop: desktop} do
    title = "GPUI Accordion E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: AccordionApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{disabled: false} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  test "desktop renders native tabs", %{desktop: desktop} do
    title = "GPUI Tabs E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: TabsApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{section: "general", selections: 0} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  test "desktop renders a native slider", %{desktop: desktop} do
    title = "GPUI Slider E2E #{System.unique_integer([:positive])}"
    runtime = start_runtime!(desktop, app: SliderApp, args: %{title: title})
    window = Desktop.window!(desktop, title)
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{volume: 25.0, released_volume: nil} = assigns(runtime)
    assert Process.alive?(runtime)
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
