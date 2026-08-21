GPUITest.Examples.load!(:beam_observatory)

defmodule GPUI.BeamObservatoryEtsSourceTest do
  use GPUI.Test, async: false

  alias Examples.BeamObservatory.EtsApp, as: App
  alias Examples.BeamObservatory.EtsModel, as: Model
  alias Examples.BeamObservatory.EtsSource, as: Source

  @source Examples.BeamObservatory.TestEtsSource
  @task_supervisor Examples.BeamObservatory.TestEtsTaskSupervisor

  test "slices, filters, sorts, and preserves distant table selection" do
    tables =
      Enum.map(0..99_999, fn index ->
        %{
          id: "table-#{index}",
          tid: nil,
          name: "table_#{String.pad_leading(Integer.to_string(index), 6, "0")}",
          owner: "<0.#{rem(index, 100)}.0>",
          type: "set",
          protection: "protected",
          size: index,
          memory: index * 2,
          named: true
        }
      end)

    request = %{
      Model.initial_request()
      | selected_table: "table-75000",
        sort_direction: "ascending",
        table_range: %{first: 74_980, last: 75_040}
    }

    snapshot = Model.snapshot(tables, [], request)

    assert snapshot.table_total == 100_000
    assert snapshot.table_offset == 74_980
    assert Enum.count_until(snapshot.tables, 257) == 60
    assert snapshot.selected_table_index == 75_000
    assert snapshot.selected_table == "table-75000"
  end

  test "supervised source inspects a live ETS table asynchronously" do
    table = :ets.new(:gpui_observatory_ets_fixture, [:set, :public])
    true = :ets.insert(table, [{:alpha, 1}, {:beta, %{status: :ready}}])
    on_exit(fn -> if :ets.info(table) != :undefined, do: :ets.delete(table) end)

    metadata = [
      %{
        id: inspect(table),
        tid: table,
        name: ":gpui_observatory_ets_fixture",
        owner: inspect(self()),
        type: "set",
        protection: "public",
        size: 2,
        memory: 32,
        named: false
      }
    ]

    runtime = start_runtime!(App, args: %{source: @source})
    assert :ok = GPUI.Runtime.subscribe(runtime)
    start_supervised!({Task.Supervisor, name: @task_supervisor})

    start_supervised!(
      {Source,
       runtime: runtime,
       name: @source,
       task_supervisor: @task_supervisor,
       interval: :infinity,
       table_source: fn -> metadata end}
    )

    await_assigns(runtime, &(&1.table_total == 1))
    assert %{type: :ui_data_table} = runtime |> tree() |> find!(id: "ets-tables")
    assert %{type: :ui_table_row} = runtime |> tree() |> find!(id: inspect(table))

    select(runtime, "table_selected", inspect(table))
    loaded = await_assigns(runtime, &(&1.entry_total == 2))

    assert loaded.selected_table == inspect(table)
    assert Enum.sort(Enum.map(loaded.entries, & &1.key)) == [":alpha", ":beta"]
    assert Enum.count_until(loaded.entries, 257) == 2
  end

  defp await_assigns(runtime, predicate) do
    current = assigns(runtime)

    if predicate.(current) do
      current
    else
      receive do
        {:gpui, ^runtime, %GPUI.Runtime.Update{}} -> await_assigns(runtime, predicate)
      after
        5_000 -> flunk("ETS inspector did not publish the expected snapshot")
      end
    end
  end
end
