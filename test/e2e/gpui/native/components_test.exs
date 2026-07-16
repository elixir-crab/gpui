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
      <div class="flex flex-col w-[360px] h-[340px] p-4 gap-4 bg-slate-900">
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
        <text class="text-white">Count: {assigns.count}; Enabled: {assigns.enabled}; Name: {assigns.name}; Language: {assigns.language}</text>
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
  end

  defmodule ComponentsApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(360, 340)
           root(ComponentsView, count: 0, enabled: false, name: "", language: "rust")
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
  end

  defp assigns(runtime) do
    %{windows: [%{root: %{assigns: assigns}}]} = GPUI.Runtime.snapshot(runtime)
    assigns
  end
end
