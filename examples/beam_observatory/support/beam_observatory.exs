Code.require_file("process_source.exs", __DIR__)
Code.require_file("ets_source.exs", __DIR__)

defmodule Examples.BeamObservatory.Sampler do
  use GenServer

  alias Examples.BeamObservatory.EtsModel, as: Model
  alias Examples.BeamObservatory.ProcessSource, as: Collector

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    state = %{
      runtime: Keyword.fetch!(opts, :runtime),
      interval: Keyword.get(opts, :interval, 1_000)
    }

    send(self(), :sample)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:sample, state) do
    sample = snapshot()
    {:ok, _snapshot} = GPUI.Runtime.send_view(state.runtime, 1, {:observatory_snapshot, sample})
    Process.send_after(self(), :sample, state.interval)
    {:noreply, state}
  end

  def snapshot do
    processes = Collector.collect()
    tables = Model.scan_tables()
    memory = :erlang.memory()
    run_queue = :erlang.statistics(:run_queue)

    %{
      processes: processes,
      tables: tables,
      memory: memory,
      run_queue: run_queue,
      schedulers: :erlang.system_info(:schedulers_online),
      ports: length(Port.list()),
      sampled_at: DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
    }
  end
end

defmodule Examples.BeamObservatory.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    filtered = filtered_processes(assigns)
    selected = Enum.find(assigns.processes, &(&1.pid == assigns.selected_pid))

    ~GPUI"""
    <div class="flex grow flex-col w-full" style={[background: {:rgb, 0x07111F}]}>
      <div class="flex items-center justify-between px-6 py-5" style={[background: {:rgb, 0x0B1728}]}>
        <div class="flex items-center gap-4">
          <div class="flex items-center justify-center w-[44px] h-[44px] rounded-lg" style={[background: {:rgb, 0x14B8A6}]}>
            <text class="text-white text-xl font-semibold">B</text>
          </div>
          <div class="flex flex-col gap-1">
            <text class="text-white text-2xl font-semibold">BEAM Observatory</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>Runtime health · sampled {assigns.sampled_at}</text>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <text style={[color: {:rgb, 0x34D399}]}>● LIVE</text>
          <UI.button id="toggle-pause" label={if(assigns.paused, do: "Resume", else: "Pause")} variant={if(assigns.paused, do: "primary", else: "default")} phx-click="toggle-pause" />
        </div>
      </div>

      <div class="flex gap-4 px-6 py-4">
        {metric_card("Processes", length(assigns.processes), "#{length(filtered)} visible", 0x38BDF8)}
        {metric_card("BEAM memory", format_bytes(assigns.memory.total), "binary #{format_bytes(assigns.memory.binary)}", 0xA78BFA)}
        {metric_card("Run queue", assigns.run_queue, "#{assigns.schedulers} schedulers", status_color(assigns.run_queue))}
        {metric_card("ETS tables", length(assigns.tables), table_memory(assigns.tables), 0xF59E0B)}
        {metric_card("Ports", assigns.ports, "native resources", 0x34D399)}
      </div>

      <div class="flex grow gap-4 px-6 pb-6">
        <div class="flex flex-col w-[300px] gap-4">
          <div class="flex flex-col gap-4 p-4 rounded-lg" style={[background: {:rgb, 0x0F1D31}]}>
            <div class="flex flex-col gap-1">
              <text class="text-white text-lg font-semibold">Memory map</text>
              <text style={[color: {:rgb, 0x94A3B8}]}>Where the VM is spending bytes</text>
            </div>
            {memory_bar("Processes", assigns.memory.processes, assigns.memory.total, 0x38BDF8)}
            {memory_bar("Binary", assigns.memory.binary, assigns.memory.total, 0xA78BFA)}
            {memory_bar("ETS", assigns.memory.ets, assigns.memory.total, 0xF59E0B)}
            {memory_bar("Code", assigns.memory.code, assigns.memory.total, 0x34D399)}
            {memory_bar("Atoms", assigns.memory.atom, assigns.memory.total, 0xFB7185)}
          </div>

          <div class="flex grow flex-col gap-3 p-4 rounded-lg" style={[background: {:rgb, 0x0F1D31}]}>
            <text class="text-white text-lg font-semibold">Runtime signals</text>
            {signal("Scheduler pressure", pressure(assigns.run_queue, assigns.schedulers), status_color(assigns.run_queue))}
            {signal("Largest mailbox", largest_mailbox(assigns.processes), 0xF59E0B)}
            {signal("Largest ETS table", largest_table(assigns.tables), 0xA78BFA)}
            {signal("Sampling", if(assigns.paused, do: "Paused", else: "Every second"), 0x34D399)}
          </div>
        </div>

        <div class="flex grow flex-col gap-3 p-4 rounded-lg" style={[background: {:rgb, 0xF8FAFC}]}>
          <div class="flex items-end justify-between gap-4">
            <div class="flex flex-col gap-1">
              <text class="text-xl font-semibold" style={[color: {:rgb, 0x0F172A}]}>Hot processes</text>
              <text style={[color: {:rgb, 0x64748B}]}>Sorted by memory with mailbox and reduction pressure</text>
            </div>
            <UI.input id="process-filter" label="Filter processes" value={assigns.query} placeholder="PID, name, or function" cleanable={true} phx-change="filter_changed" />
          </div>
          {process_table(filtered, assigns.selected_pid)}
        </div>

        <div class="flex flex-col w-[330px] gap-4 p-5 rounded-lg" style={[background: {:rgb, 0x0F1D31}]}>
          {process_inspector(selected)}
          <div class="flex flex-col gap-3">
            <div class="flex items-center justify-between">
              <text class="text-white text-lg font-semibold">Largest ETS tables</text>
              <text style={[color: {:rgb, 0xF59E0B}]}>{length(assigns.tables)}</text>
            </div>
            {table_rankings(assigns.tables)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("toggle-pause", _event, assigns),
    do: {:noreply, %{assigns | paused: not assigns.paused}}

  def handle_event("filter_changed", %{value: query}, assigns),
    do: {:noreply, %{assigns | query: query}}

  def handle_event("process_selected", %{value: pid}, assigns),
    do: {:noreply, %{assigns | selected_pid: pid}}

  @impl GPUI.View
  def handle_info({:observatory_snapshot, _snapshot}, %{paused: true} = assigns),
    do: {:noreply, assigns}

  def handle_info({:observatory_snapshot, snapshot}, assigns) do
    selected_pid =
      if Enum.any?(snapshot.processes, &(&1.pid == assigns.selected_pid)),
        do: assigns.selected_pid

    {:noreply, assigns |> Map.merge(snapshot) |> Map.put(:selected_pid, selected_pid)}
  end

  defp metric_card(label, value, detail, color) do
    assigns = %{label: label, value: value, detail: detail, color: color}

    ~GPUI"""
    <div class="flex grow flex-col gap-2 p-4 rounded-lg" style={[background: {:rgb, 0x0F1D31}]}>
      <div class="flex items-center gap-2"><div class="w-[8px] h-[8px] rounded-full" style={[background: {:rgb, assigns.color}]} /><text style={[color: {:rgb, 0x94A3B8}]}>{assigns.label}</text></div>
      <text class="text-white text-2xl font-semibold">{assigns.value}</text>
      <text style={[color: {:rgb, 0x64748B}]}>{assigns.detail}</text>
    </div>
    """
  end

  defp memory_bar(label, value, total, color) do
    width = if total > 0, do: max(round(value / total * 230), 4), else: 4
    assigns = %{label: label, value: value, width: width, color: color}

    ~GPUI"""
    <div class="flex flex-col gap-1">
      <div class="flex justify-between"><text style={[color: {:rgb, 0xCBD5E1}]}>{assigns.label}</text><text style={[color: {:rgb, 0x94A3B8}]}>{format_bytes(assigns.value)}</text></div>
      <div class="flex h-[8px] rounded-full" style={[background: {:rgb, 0x26364D}]}><div class="h-[8px] rounded-full" style={[width: {:px, assigns.width}, background: {:rgb, assigns.color}]} /></div>
    </div>
    """
  end

  defp signal(label, value, color) do
    assigns = %{label: label, value: value, color: color}

    ~GPUI"""
    <div class="flex items-center justify-between gap-3 p-3 rounded-md" style={[background: {:rgb, 0x15243A}]}>
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.label}</text>
      <text class="font-semibold" style={[color: {:rgb, assigns.color}]}>{assigns.value}</text>
    </div>
    """
  end

  defp process_table([], _selected) do
    ~GPUI"""
    <div class="flex grow items-center justify-center"><text style={[color: {:rgb, 0x64748B}]}>No matching processes</text></div>
    """
  end

  defp process_table(processes, selected) do
    columns = [
      UI.table_column(%{id: "process", label: "Process", width: 140}),
      UI.table_column(%{id: "name", label: "Name / function", width: 260}),
      UI.table_column(%{id: "memory", label: "Memory", width: 120, align: "right"}),
      UI.table_column(%{id: "mailbox", label: "Mailbox", width: 100, align: "right"}),
      UI.table_column(%{id: "reductions", label: "Reductions", width: 140, align: "right"})
    ]

    rows =
      Enum.map(processes, fn process ->
        UI.table_row(%{
          id: process.pid,
          children: [
            process.pid,
            process.name <> "\n" <> process.current_function,
            format_bytes(process.memory),
            Integer.to_string(process.message_queue_len),
            format_integer(process.reductions)
          ]
        })
      end)

    UI.data_table(%{
      id: "observatory-processes",
      label: "Hot processes",
      selected: selected,
      reveal: selected,
      item_height: 58,
      header_height: 44,
      "phx-change": "process_selected",
      class: "grow",
      children: columns ++ rows
    })
  end

  defp process_inspector(nil) do
    ~GPUI"""
    <div class="flex flex-col gap-2 p-4 rounded-lg" style={[background: {:rgb, 0x15243A}]}>
      <text class="text-white text-lg font-semibold">Process inspector</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Select a hot process to inspect its runtime state.</text>
    </div>
    """
  end

  defp process_inspector(process) do
    assigns = %{process: process}

    ~GPUI"""
    <div class="flex flex-col gap-3 p-4 rounded-lg" style={[background: {:rgb, 0x15243A}]}>
      <text class="text-white text-lg font-semibold">{assigns.process.pid}</text>
      <text style={[color: {:rgb, 0x38BDF8}]}>{assigns.process.name}</text>
      {detail("Status", assigns.process.status)}
      {detail("Current function", assigns.process.current_function)}
      {detail("Memory", format_bytes(assigns.process.memory))}
      {detail("Mailbox", assigns.process.message_queue_len)}
    </div>
    """
  end

  defp detail(label, value) do
    assigns = %{label: label, value: value}

    ~GPUI"""
    <div class="flex flex-col gap-1"><text style={[color: {:rgb, 0x64748B}]}>{assigns.label}</text><text class="text-white">{assigns.value}</text></div>
    """
  end

  defp table_rankings(tables) do
    tables
    |> Enum.sort_by(& &1.memory, :desc)
    |> Enum.take(5)
    |> Enum.with_index(1)
    |> Enum.map(fn {table, rank} -> ranking(table, rank) end)
  end

  defp ranking(table, rank) do
    assigns = %{table: table, rank: rank}

    ~GPUI"""
    <div class="flex items-center gap-3"><text style={[color: {:rgb, 0x64748B}]}>{assigns.rank}</text><div class="flex grow flex-col"><text class="text-white">{assigns.table.name}</text><text style={[color: {:rgb, 0x94A3B8}]}>{assigns.table.size} objects · {assigns.table.memory} words</text></div></div>
    """
  end

  defp filtered_processes(assigns) do
    query = assigns.query |> String.trim() |> String.downcase()

    assigns.processes
    |> Enum.filter(fn process ->
      query == "" or
        Enum.any?(
          [process.pid, process.name, process.current_function],
          &String.contains?(String.downcase(&1), query)
        )
    end)
    |> Enum.sort_by(& &1.memory, :desc)
    |> Enum.take(200)
  end

  defp table_memory(tables), do: "#{Enum.reduce(tables, 0, &(&1.memory + &2))} words"
  defp largest_mailbox([]), do: "0 messages"

  defp largest_mailbox(processes),
    do: "#{Enum.max_by(processes, & &1.message_queue_len).message_queue_len} messages"

  defp largest_table([]), do: "None"
  defp largest_table(tables), do: Enum.max_by(tables, & &1.memory).name
  defp pressure(run_queue, schedulers) when run_queue > schedulers, do: "High"
  defp pressure(run_queue, _schedulers) when run_queue > 0, do: "Active"
  defp pressure(_run_queue, _schedulers), do: "Idle"
  defp status_color(run_queue) when run_queue > 8, do: 0xFB7185
  defp status_color(run_queue) when run_queue > 0, do: 0xF59E0B
  defp status_color(_run_queue), do: 0x34D399

  defp format_bytes(bytes) when bytes >= 1_048_576,
    do: :erlang.float_to_binary(bytes / 1_048_576, decimals: 1) <> " MB"

  defp format_bytes(bytes) when bytes >= 1_024,
    do: :erlang.float_to_binary(bytes / 1_024, decimals: 1) <> " KB"

  defp format_bytes(bytes), do: "#{bytes} B"

  defp format_integer(value),
    do:
      value
      |> Integer.to_string()
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &Enum.join/1)
      |> String.reverse()
end

defmodule Examples.BeamObservatory.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    snapshot =
      args |> Map.new() |> Map.get_lazy(:snapshot, &Examples.BeamObservatory.Sampler.snapshot/0)

    {:ok,
     [
       window "BEAM Observatory" do
         size(1440, 860)

         root(
           Examples.BeamObservatory.View,
           Map.merge(snapshot, %{paused: false, query: "", selected_pid: nil})
         )
       end
     ]}
  end
end
