defmodule GPUI.Remote.NativeDisplayE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.E2E.Desktop

  @moduletag :e2e

  defmodule CounterView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-start w-full h-full bg-slate-900 text-white text-2xl p-4 gap-2">
        <text>Count: {assigns.count}</text>
        <GPUI.UI.combobox
          id="remote-framework"
          value={assigns.framework}
          options={assigns.framework_options}
          phx-change="framework_changed"
          phx-search="framework_searched"
        />
        <GPUI.UI.button id="remote-increment" label="Increment" variant="primary" phx-click="inc" />
        <GPUI.UI.input
          id="remote-name"
          value={assigns.name}
          placeholder="Name"
          phx-change="name_changed"
        />
        <GPUI.UI.select
          id="remote-language"
          value={assigns.language}
          options={[{"Rust", "rust"}, {"Elixir", "elixir"}]}
          phx-change="language_changed"
        />
        <GPUI.UI.slider
          id="remote-volume"
          class="w-full h-[32px]"
          value={assigns.volume}
          step={10}
          phx-change="volume_changed"
          phx-release="volume_released"
        />
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("inc", _event, assigns),
      do: {:noreply, %{assigns | count: assigns.count + 1}}

    def handle_event("name_changed", %{value: name}, assigns),
      do: {:noreply, %{assigns | name: name}}

    def handle_event("language_changed", %{value: language}, assigns),
      do: {:noreply, %{assigns | language: language}}

    def handle_event("framework_changed", %{value: framework}, assigns),
      do: {:noreply, %{assigns | framework: framework}}

    def handle_event("framework_searched", %{value: query}, assigns) do
      options = Enum.filter(["Phoenix", "LiveView"], &contains?(&1, query))
      {:noreply, %{assigns | query: query, framework_options: options}}
    end

    def handle_event("volume_changed", %{value: volume}, assigns),
      do: {:noreply, %{assigns | volume: volume}}

    def handle_event("volume_released", %{value: volume}, assigns),
      do: {:noreply, %{assigns | released_volume: volume}}

    defp contains?(label, query),
      do: String.contains?(String.downcase(label), String.downcase(query))
  end

  defmodule CounterApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote E2E" do
           size(320, 320)

           root(CounterView,
             count: 0,
             name: "",
             language: "rust",
             framework: nil,
             query: "",
             framework_options: ["Phoenix", "LiveView"],
             volume: 0.0,
             released_volume: nil
           )
         end
       ]}
    end
  end

  defmodule ControlledView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[360px] h-[220px] p-4 gap-2 bg-slate-900">
        <GPUI.UI.tabs
          id="remote-tabs"
          value={assigns.section}
          options={[{"General", "general"}, {"Advanced", "advanced"}]}
          variant="segmented"
          phx-change="section_changed"
        />
        <GPUI.UI.accordion
          id="remote-accordion"
          expanded={assigns.expanded}
          multiple={true}
          phx-change="details_changed"
        >
          <GPUI.UI.accordion_item id="account" title="Account" />
          <GPUI.UI.accordion_item id="security" title="Security" />
        </GPUI.UI.accordion>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("section_changed", %{value: section}, assigns),
      do: {:noreply, %{assigns | section: section}}

    def handle_event("details_changed", %{value: expanded}, assigns),
      do: {:noreply, %{assigns | expanded: expanded}}
  end

  defmodule ControlledApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote Controls E2E" do
           size(360, 220)
           root(ControlledView, section: "general", expanded: [])
         end
       ]}
    end
  end

  defmodule CodeView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      lines =
        Enum.map(1..8, fn number ->
          GPUI.UI.code_line(%{
            id: "line-#{number}",
            number: number,
            text: if(rem(number, 2) == 0, do: "+remote #{number}", else: " remote #{number}"),
            kind:
              cond do
                number == 2 -> "warning"
                rem(number, 2) == 0 -> "addition"
                true -> "context"
              end
          })
        end)

      assigns = Map.put(assigns, :lines, lines)

      ~GPUI"""
      <div class="w-[420px] h-[220px] bg-slate-900">
        <GPUI.UI.code_viewer
          id="remote-code"
          label="Remote code"
          mode="diff"
          selected={assigns.selected}
          max_columns={80}
          phx-change="remote_line_selected"
          phx-copy="remote_line_copied"
          class="h-[200px]"
        >
          {assigns.lines}
        </GPUI.UI.code_viewer>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("remote_line_selected", %{value: selected}, assigns),
      do: {:noreply, %{assigns | selected: selected}}

    def handle_event("remote_line_copied", _event, assigns),
      do: {:noreply, %{assigns | copies: assigns.copies + 1}}
  end

  defmodule CodeApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote Code E2E" do
           size(420, 220)
           root(CodeView, selected: nil, copies: 0)
         end
       ]}
    end
  end

  defmodule TableView do
    use GPUI.View

    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      columns = [
        UI.table_column(%{id: "name", label: "Name", width: 240, sortable: true}),
        UI.table_column(%{id: "value", label: "Value", width: 180, align: "right"})
      ]

      rows =
        Enum.map(1..3, fn index ->
          UI.table_row(%{
            id: "row-#{index}",
            children: ["remote-#{index}", Integer.to_string(index)]
          })
        end)

      ~GPUI"""
      <div class="w-[480px] h-[240px] bg-slate-900">
        <UI.data_table
          id="remote-table"
          label="Remote records"
          selected={assigns.selected}
          selected_column={assigns.selected_column}
          sort_column="name"
          sort_direction={assigns.sort_direction}
          phx-change="remote_row_selected"
          phx-cell-change="remote_cell_selected"
          phx-sort="remote_table_sorted"
          class="h-[220px]"
        >
          {columns ++ rows}
        </UI.data_table>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("remote_row_selected", %{value: selected}, assigns),
      do: {:noreply, %{assigns | selected: selected}}

    def handle_event("remote_cell_selected", %{value: [selected, column]}, assigns),
      do: {:noreply, %{assigns | selected: selected, selected_column: column}}

    def handle_event("remote_table_sorted", _event, assigns) do
      direction = if assigns.sort_direction == "ascending", do: "descending", else: "ascending"
      {:noreply, %{assigns | sort_direction: direction}}
    end
  end

  defmodule TableApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Remote Table E2E" do
           size(480, 240)
           root(TableView, selected: nil, selected_column: nil, sort_direction: "ascending")
         end
       ]}
    end
  end

  test "a TCP session renders through the real native display" do
    client = start_remote!(CounterApp)

    assert {:ok, %{windows: [window]}} = GPUI.Remote.Client.mount(client)
    :ok = GPUI.Remote.Client.subscribe(client)
    assert 0 = get_in(window, [:root, :assigns, :count])
    assert "" = get_in(window, [:root, :assigns, :name])
    assert "rust" = get_in(window, [:root, :assigns, :language])
    assert nil == get_in(window, [:root, :assigns, :framework])
    assert get_in(window, [:root, :assigns, :volume]) == 0.0

    window_id = Desktop.window_id!("GPUI Remote E2E")
    Desktop.click!(window_id, 80, 68)
    Desktop.click!(window_id, 80, 173)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "LiveView" = get_in(updated, [:root, :assigns, :framework])
    end)

    Desktop.click!(window_id, 80, 110)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert 1 = get_in(updated, [:root, :assigns, :count])
    end)

    Desktop.click!(window_id, 80, 150)
    Desktop.type!(window_id, "remote")

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "remote" = get_in(updated, [:root, :assigns, :name])
    end)

    Desktop.request_frame!(window_id)
    assert :ok = GPUI.Remote.Client.await_frame(client, 1)
    Desktop.click!(window_id, 160, 239)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert 50.0 = get_in(updated, [:root, :assigns, :volume])
    end)

    Desktop.click!(window_id, 80, 190)
    Desktop.click!(window_id, 80, 263)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "elixir" = get_in(updated, [:root, :assigns, :language])
    end)
  end

  test "controlled tabs and accordion interact through a remote native display" do
    client = start_remote!(ControlledApp)

    assert {:ok, %{windows: [_window]}} = GPUI.Remote.Client.mount(client)
    :ok = GPUI.Remote.Client.subscribe(client)
    window_id = Desktop.window_id!("GPUI Remote Controls E2E")
    Desktop.click!(window_id, 130, 32)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "advanced" = get_in(updated, [:root, :assigns, :section])
    end)

    Desktop.click!(window_id, 100, 118)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert ["security"] = get_in(updated, [:root, :assigns, :expanded])
    end)
  end

  test "data-table sorting and cell selection cross a remote native session" do
    client = start_remote!(TableApp)

    assert {:ok, %{windows: [_window]}} = GPUI.Remote.Client.mount(client)
    :ok = GPUI.Remote.Client.subscribe(client)
    window_id = Desktop.window_id!("GPUI Remote Table E2E")

    Desktop.click!(window_id, 100, 20)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "descending" = get_in(updated, [:root, :assigns, :sort_direction])
    end)

    Desktop.click!(window_id, 100, 65)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "row-1" = get_in(updated, [:root, :assigns, :selected])
      assert "name" = get_in(updated, [:root, :assigns, :selected_column])
    end)
  end

  test "code selection and display-side copy acknowledgements cross a remote session" do
    client = start_remote!(CodeApp)

    assert {:ok, %{windows: [_window]}} = GPUI.Remote.Client.mount(client)
    :ok = GPUI.Remote.Client.subscribe(client)
    window_id = Desktop.window_id!("GPUI Remote Code E2E")
    Desktop.click!(window_id, 120, 36)

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert "line-2" = get_in(updated, [:root, :assigns, :selected])
    end)

    Desktop.key!(window_id, "ctrl+c")

    Desktop.eventually(fn ->
      assert {:ok, %{windows: [updated]}} = GPUI.Remote.Client.snapshot(client)
      assert 1 = get_in(updated, [:root, :assigns, :copies])
    end)
  end

  defp start_remote!(app) do
    port = available_port()
    {:ok, server} = GPUI.Remote.Server.start_link(app: app, port: port)

    {:ok, client} =
      GPUI.Remote.Client.start_link(
        host: "127.0.0.1",
        port: port,
        display: GPUI.Display.Native,
        poll_interval: 10
      )

    on_exit(fn -> Desktop.stop_process(client) end)
    on_exit(fn -> Desktop.stop_process(server) end)
    client
  end

  defp available_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_address, port}} = :inet.sockname(socket)
    :ok = :gen_tcp.close(socket)
    port
  end
end
