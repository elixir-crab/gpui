Code.require_file(
  "../../../examples/ets_table_explorer/support/ets_table_explorer.exs",
  __DIR__
)

defmodule GPUITest.Visual.EtsTableExplorer.Fixture do
  def snapshot(selected_entry_id \\ nil) do
    tables =
      Enum.map(1..8, fn index ->
        %{
          id: "table-#{index}",
          tid: nil,
          name: ":table_#{index}",
          owner: "<0.#{40 + index}.0>",
          type: if(rem(index, 2) == 0, do: "ordered_set", else: "set"),
          protection: "protected",
          size: index * 120,
          memory: index * 640,
          named: true
        }
      end)

    entries =
      Enum.map(1..12, fn index ->
        object = "{:session_#{index}, %{status: :ready, attempts: #{rem(index, 4)}}}"

        %{
          id: "entry-#{index}",
          key: ":session_#{index}",
          value: "%{status: :ready, attempts: #{rem(index, 4)}}",
          bytes: 48 + index,
          object: object
        }
      end)

    selected_entry = Enum.find(entries, &(&1.id == selected_entry_id))
    selected_entry_index = Enum.find_index(entries, &(&1.id == selected_entry_id))

    %{
      tables: tables,
      table_total: length(tables),
      table_offset: 0,
      selected_table: "table-8",
      selected_table_index: 7,
      selected_table_metadata: List.last(tables),
      entries: entries,
      entry_total: length(entries),
      entry_offset: 0,
      selected_entry_id: selected_entry_id,
      selected_entry_index: selected_entry_index,
      selected_entry: selected_entry
    }
  end
end

defmodule GPUITest.Visual.EtsTableExplorer.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    assigns =
      Examples.EtsTableExplorer.Model.initial_request()
      |> Map.merge(GPUITest.Visual.EtsTableExplorer.Fixture.snapshot())
      |> Map.merge(%{source: GPUITest.Visual.MissingEtsSource, status: :ready})

    {:ok,
     [
       window "ETS Table Explorer Visual" do
         size(1280, 760)
         root(Examples.EtsTableExplorer.View, assigns)
       end
     ]}
  end
end

defmodule GPUITest.Visual.EtsTableExplorer.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :ets_table_explorer

  @impl GPUI.Dev.Visual.Scenario
  def app, do: GPUITest.Visual.EtsTableExplorer.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "ETS Table Explorer Visual"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "tables-and-entries"},
      %{
        name: "selected-object",
        actions: [
          {:send_view_from, 1,
           fn assigns ->
             {:ets_snapshot, assigns.generation,
              GPUITest.Visual.EtsTableExplorer.Fixture.snapshot("entry-4")}
           end}
        ]
      }
    ]
  end
end
