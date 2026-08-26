defmodule Examples.BeamObservatory.EtsModel do
  @moduledoc false

  @max_tables 10_000
  @max_entries 5_000
  @max_loaded 256
  @inspect_limit 2_000

  def scan_tables do
    :ets.all()
    |> Enum.take(@max_tables)
    |> Enum.flat_map(&table_metadata/1)
  end

  def load_entries(table) do
    case :ets.select(table.tid, [{:"$1", [], [:"$1"]}], @max_entries) do
      {objects, _continuation} ->
        objects
        |> Enum.with_index()
        |> Enum.map(fn {object, index} -> entry(object, index) end)

      :"$end_of_table" ->
        []
    end
  catch
    :error, _reason -> []
  end

  def snapshot(tables, entries, request) do
    filtered = filter_tables(tables, request.query)
    sorted = sort_tables(filtered, request.sort_column, request.sort_direction)
    selected_index = Enum.find_index(sorted, &(&1.id == request.selected_table))
    {table_offset, loaded_tables} = slice(sorted, request.table_range)
    {entry_offset, loaded_entries} = slice(entries, request.entry_range)
    selected_entry_index = Enum.find_index(entries, &(&1.id == request.selected_entry_id))

    %{
      tables: loaded_tables,
      table_total: length(sorted),
      table_offset: table_offset,
      selected_table: selected_index && request.selected_table,
      selected_table_index: selected_index,
      entries: loaded_entries,
      entry_total: length(entries),
      entry_offset: entry_offset,
      selected_entry_id: selected_entry_index && request.selected_entry_id,
      selected_entry_index: selected_entry_index,
      selected_entry: selected_entry(entries, request.selected_entry_id),
      selected_table_metadata: Enum.find(tables, &(&1.id == request.selected_table))
    }
  end

  def initial_request do
    %{
      generation: 0,
      query: "",
      sort_column: "memory",
      sort_direction: "descending",
      selected_table: nil,
      selected_entry_id: nil,
      table_range: %{first: 0, last: 48},
      entry_range: %{first: 0, last: 48}
    }
  end

  defp table_metadata(tid) do
    with name when not is_nil(name) <- :ets.info(tid, :name),
         owner when is_pid(owner) <- :ets.info(tid, :owner) do
      [
        %{
          id: inspect(tid),
          tid: tid,
          name: inspect(name),
          owner: inspect(owner),
          type: to_string(:ets.info(tid, :type)),
          protection: to_string(:ets.info(tid, :protection)),
          size: :ets.info(tid, :size) || 0,
          memory: :ets.info(tid, :memory) || 0,
          named: :ets.info(tid, :named_table) == true
        }
      ]
    else
      _missing -> []
    end
  rescue
    ArgumentError -> []
  end

  defp entry(object, index) do
    {key, value} = split_object(object)
    rendered = bounded_inspect(object)

    %{
      id: "entry-#{index}-#{:erlang.phash2(object)}-#{byte_size(rendered)}",
      key: bounded_inspect(key),
      value: bounded_inspect(value),
      bytes: safe_external_size(object),
      object: rendered
    }
  end

  defp split_object(object) when is_tuple(object) and tuple_size(object) > 0 do
    key = elem(object, 0)
    value = object |> Tuple.to_list() |> tl()
    {key, if(match?([_], value), do: hd(value), else: List.to_tuple(value))}
  end

  defp split_object(object), do: {object, object}

  defp safe_external_size(object) do
    :erlang.external_size(object)
  rescue
    _error -> 0
  end

  defp bounded_inspect(value),
    do: inspect(value, limit: 30, printable_limit: @inspect_limit, width: 100)

  defp filter_tables(tables, query) do
    query = query |> String.trim() |> String.downcase()

    if query == "" do
      tables
    else
      Enum.filter(tables, fn table ->
        Enum.any?([table.name, table.owner, table.type, table.protection], fn value ->
          value |> String.downcase() |> String.contains?(query)
        end)
      end)
    end
  end

  defp sort_tables(tables, column, direction) do
    direction = if direction == "ascending", do: :asc, else: :desc
    Enum.sort_by(tables, &sort_value(&1, column), direction)
  end

  defp sort_value(table, "name"), do: table.name
  defp sort_value(table, "size"), do: table.size
  defp sort_value(table, "owner"), do: table.owner
  defp sort_value(table, _column), do: table.memory

  defp slice(items, %{first: first, last: last}) do
    total = length(items)
    first = first |> max(0) |> min(total)
    last = last |> max(first) |> min(total) |> min(first + @max_loaded)
    {first, Enum.slice(items, first, last - first)}
  end

  defp selected_entry(_entries, nil), do: nil
  defp selected_entry(entries, id), do: Enum.find(entries, &(&1.id == id))
end

defmodule Examples.BeamObservatory.EtsSource do
  @moduledoc false

  use GenServer

  alias Examples.BeamObservatory.EtsModel, as: Model

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))

  def request(source, request), do: GenServer.cast(source, {:request, request})
  def refresh(source), do: GenServer.cast(source, :refresh)

  @impl GenServer
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    request = Keyword.get(opts, :request, Model.initial_request())

    state = %{
      runtime: GenServer.whereis(runtime) || runtime,
      interval: Keyword.get(opts, :interval, 2_000),
      tables: table_source(opts).(),
      entries: [],
      request: request,
      operation: 0,
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      table_source: table_source(opts)
    }

    send(self(), :publish)
    schedule_refresh(state.interval)
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:request, request}, state) do
    selected_changed? = request.selected_table != state.request.selected_table
    state = %{state | request: request}

    if selected_changed? do
      {:noreply, load_selected(state)}
    else
      send(self(), :publish)
      {:noreply, state}
    end
  end

  def handle_cast(:refresh, state), do: {:noreply, refresh_tables(state)}

  @impl GenServer
  def handle_info(:refresh, state) do
    state = refresh_tables(state)
    schedule_refresh(state.interval)
    {:noreply, state}
  end

  def handle_info(:publish, state) do
    publish(state)
    {:noreply, state}
  end

  def handle_info({ref, {:entries, operation, entries}}, %{operation: operation} = state)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    state = %{state | entries: entries}
    publish(state)
    {:noreply, state}
  end

  def handle_info({ref, {:entries, _operation, _entries}}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state), do: {:noreply, state}

  defp refresh_tables(state) do
    state = %{state | tables: state.table_source.()}

    if Enum.any?(state.tables, &(&1.id == state.request.selected_table)) do
      load_selected(state)
    else
      send(self(), :publish)
      %{state | entries: [], operation: state.operation + 1}
    end
  end

  defp load_selected(state) do
    operation = state.operation + 1
    table = Enum.find(state.tables, &(&1.id == state.request.selected_table))

    if table do
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        {:entries, operation, Model.load_entries(table)}
      end)
    end

    send(self(), :publish)
    %{state | entries: [], operation: operation}
  end

  defp publish(state) do
    snapshot = Model.snapshot(state.tables, state.entries, state.request)

    GPUI.Runtime.send_view(
      state.runtime,
      1,
      {:ets_snapshot, state.request.generation, snapshot}
    )
  end

  defp schedule_refresh(:infinity), do: :ok
  defp schedule_refresh(interval), do: Process.send_after(self(), :refresh, interval)
  defp table_source(opts), do: Keyword.get(opts, :table_source, &Model.scan_tables/0)
end

defmodule Examples.BeamObservatory.EtsView do
  use GPUI.View

  alias Examples.BeamObservatory.EtsModel, as: Model
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    selected = if is_integer(assigns.selected_table_index), do: assigns.selected_table

    ~GPUI"""
    <div class="flex flex-col w-[1280px] h-[760px] bg-slate-900">
      <div class="flex flex-col gap-3 p-4" style={[background: {:rgb, 0x1E293B}]}>
        <div class="flex items-center justify-between gap-4">
          <div class="flex flex-col gap-1">
            <text class="text-white text-2xl font-semibold">ETS table inspector</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>{summary(assigns)}</text>
          </div>
          <UI.button id="refresh-tables" label="Refresh" phx-click="refresh_tables" />
        </div>
        <UI.input
          id="table-filter"
          label="Table filter"
          value={assigns.query}
          placeholder="Filter by table name, owner, type, or protection"
          cleanable={true}
          phx-change="filter_changed"
        />
      </div>

      <div class="flex h-[620px]">
        <div class="w-[720px] h-[620px]" style={[background: {:rgb, 0x0F172A}]}>
          <UI.data_table
            id="ets-tables"
            label="ETS tables"
            total_count={assigns.table_total}
            offset={assigns.table_offset}
            selected={selected}
            selected_index={assigns.selected_table_index}
            reveal={selected}
            reveal_index={assigns.selected_table_index}
            sort_column={assigns.sort_column}
            sort_direction={assigns.sort_direction}
            item_height={46}
            phx-change="table_selected"
            phx-sort="table_sorted"
            phx-range="tables_range"
            class="h-[620px]"
          >
            {table_columns() ++ Enum.map(assigns.tables, &table_row/1)}
          </UI.data_table>
        </div>

        <div class="flex flex-col w-[560px] h-[620px]" style={[background: {:rgb, 0x111827}]}>
          {entry_panel(assigns)}
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("filter_changed", %{value: query}, assigns),
    do:
      update_request(assigns, %{query: String.slice(query, 0, 256), table_range: initial_range()})

  def handle_event("tables_range", %{value: range}, assigns),
    do: update_request(assigns, %{table_range: range})

  def handle_event("entries_range", %{value: range}, assigns),
    do: update_request(assigns, %{entry_range: range})

  def handle_event("table_sorted", %{value: column}, assigns) do
    direction = next_direction(assigns, column)
    update_request(assigns, %{sort_column: column, sort_direction: direction})
  end

  def handle_event("table_selected", %{value: id}, assigns),
    do:
      update_request(assigns, %{
        selected_table: id,
        selected_entry_id: nil,
        entry_range: initial_range()
      })

  def handle_event("entry_selected", %{value: id}, assigns),
    do: update_request(assigns, %{selected_entry_id: id})

  def handle_event("refresh_tables", _event, assigns) do
    if source = GenServer.whereis(assigns.source),
      do: Examples.BeamObservatory.EtsSource.refresh(source)

    {:noreply, assigns}
  end

  @impl GPUI.View
  def handle_info({:ets_snapshot, generation, snapshot}, %{generation: generation} = assigns) do
    {:noreply,
     assigns
     |> Map.merge(snapshot)
     |> Map.put(:status, :ready)}
  end

  def handle_info({:ets_snapshot, _generation, _snapshot}, assigns), do: {:noreply, assigns}
  def handle_info(_message, assigns), do: {:noreply, assigns}

  defp update_request(assigns, changes) do
    assigns =
      assigns
      |> Map.merge(changes)
      |> Map.update!(:generation, &(&1 + 1))
      |> Map.put(:status, :loading)

    if source = GenServer.whereis(assigns.source) do
      Examples.BeamObservatory.EtsSource.request(source, request(assigns))
    end

    {:noreply, assigns}
  end

  defp request(assigns),
    do: Map.take(assigns, Map.keys(Model.initial_request()))

  defp table_columns do
    [
      UI.table_column(%{id: "name", label: "Table", width: 230, sortable: true}),
      UI.table_column(%{
        id: "size",
        label: "Objects",
        width: 110,
        align: "right",
        sortable: true
      }),
      UI.table_column(%{
        id: "memory",
        label: "Words",
        width: 110,
        align: "right",
        sortable: true
      }),
      UI.table_column(%{id: "owner", label: "Owner", width: 180, sortable: true}),
      UI.table_column(%{id: "type", label: "Type", width: 90})
    ]
  end

  defp table_row(table) do
    UI.table_row(%{
      id: table.id,
      children: [
        table.name,
        Integer.to_string(table.size),
        Integer.to_string(table.memory),
        table.owner,
        table.type
      ]
    })
  end

  defp entry_panel(%{selected_table_metadata: nil}) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center h-[620px] gap-2 p-6">
      <text class="text-white text-lg">Select an ETS table</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Objects are loaded asynchronously and bounded to 5,000 entries.</text>
    </div>
    """
  end

  defp entry_panel(assigns) do
    panel = %{assigns: assigns, selected: assigns.selected_entry}

    ~GPUI"""
    <div class="flex flex-col h-[620px]">
      <div class="flex flex-col gap-1 p-3" style={[background: {:rgb, 0x1E293B}]}>
        <text class="text-white font-semibold">{panel.assigns.selected_table_metadata.name}</text>
        <text style={[color: {:rgb, 0x94A3B8}]}>{table_details(panel.assigns.selected_table_metadata)}</text>
      </div>
      <UI.data_table
        id="ets-entries"
        label="ETS objects"
        total_count={panel.assigns.entry_total}
        offset={panel.assigns.entry_offset}
        selected={panel.selected && panel.selected.id}
        selected_index={panel.assigns.selected_entry_index}
        reveal={panel.selected && panel.selected.id}
        reveal_index={panel.assigns.selected_entry_index}
        item_height={44}
        phx-change="entry_selected"
        phx-range="entries_range"
        class="h-[400px]"
      >
        {entry_columns() ++ Enum.map(panel.assigns.entries, &entry_row/1)}
      </UI.data_table>
      {entry_details(panel.selected)}
    </div>
    """
  end

  defp entry_columns do
    [
      UI.table_column(%{id: "key", label: "Key", width: 170}),
      UI.table_column(%{id: "value", label: "Value", width: 260}),
      UI.table_column(%{id: "bytes", label: "Bytes", width: 90, align: "right"})
    ]
  end

  defp entry_row(entry),
    do:
      UI.table_row(%{
        id: entry.id,
        children: [entry.key, entry.value, Integer.to_string(entry.bytes)]
      })

  defp entry_details(nil) do
    ~GPUI"""
    <div />
    """
  end

  defp entry_details(entry) do
    assigns = %{entry: entry}

    ~GPUI"""
    <div class="flex flex-col h-[100px] gap-1 p-3">
      <text style={[color: {:rgb, 0x94A3B8}]}>Selected object</text>
      <text class="text-white">{assigns.entry.object}</text>
    </div>
    """
  end

  defp summary(assigns) do
    state = if assigns.status == :loading, do: "loading", else: "ready"
    "#{assigns.table_total} tables · #{assigns.entry_total} loaded objects · #{state}"
  end

  defp table_details(table),
    do: "#{table.type} · #{table.protection} · owner #{table.owner}"

  defp next_direction(assigns, column) do
    if assigns.sort_column == column and assigns.sort_direction == "ascending",
      do: "descending",
      else: "ascending"
  end

  defp initial_range, do: %{first: 0, last: 48}
end

defmodule Examples.BeamObservatory.EtsApp do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    request = Examples.BeamObservatory.EtsModel.initial_request()

    {:ok,
     [
       window "ETS Table Inspector" do
         size(1280, 760)

         root(
           Examples.BeamObservatory.EtsView,
           Map.merge(request, %{
             source: Map.get(args, :source, Examples.BeamObservatory.EtsSource),
             tables: [],
             table_total: 0,
             table_offset: 0,
             selected_table_index: nil,
             selected_table_metadata: nil,
             selected_entry_index: nil,
             entries: [],
             entry_total: 0,
             entry_offset: 0,
             status: :loading
           })
         )
       end
     ]}
  end
end

defmodule Examples.BeamObservatory.EtsSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  @impl Supervisor
  def init(opts) do
    source = Keyword.get(opts, :source, Examples.BeamObservatory.EtsSource)
    task_supervisor = Module.concat(source, TaskSupervisor)

    children = [
      {Task.Supervisor, name: task_supervisor},
      {Examples.BeamObservatory.EtsSource,
       runtime: Keyword.fetch!(opts, :runtime),
       name: source,
       task_supervisor: task_supervisor,
       interval: Keyword.get(opts, :interval, 2_000),
       table_source:
         Keyword.get(opts, :table_source, &Examples.BeamObservatory.EtsModel.scan_tables/0)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
