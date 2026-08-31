Code.require_file("process_source.exs", __DIR__)
Code.require_file("ets_source.exs", __DIR__)

defmodule Examples.BeamControlRoom.Sampler do
  use GenServer

  alias Examples.BeamControlRoom.EtsModel
  alias Examples.BeamControlRoom.ProcessSource

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    state = %{runtime: Keyword.fetch!(opts, :runtime), interval: Keyword.get(opts, :interval, 1_000)}
    send(self(), :sample)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:sample, state) do
    {:ok, _snapshot} = GPUI.Runtime.send_view(state.runtime, 1, {:control_room_snapshot, snapshot()})
    Process.send_after(self(), :sample, state.interval)
    {:noreply, state}
  end

  def snapshot do
    %{
      processes: ProcessSource.collect(),
      tables: EtsModel.scan_tables(),
      memory: :erlang.memory() |> Map.new(),
      run_queue: :erlang.statistics(:run_queue),
      schedulers: :erlang.system_info(:schedulers_online),
      ports: length(Port.list()),
      sampled_at: DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
    }
  end
end

defmodule Examples.BeamControlRoom.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    processes = filtered_processes(assigns)
    selected = Enum.find(assigns.processes, &(&1.pid == assigns.selected_pid))

    ~GPUI"""
    <div class="flex w-full h-full min-h-0 flex-col bg-white">
      <div class="flex items-center justify-between px-4 py-3 border-b border-slate-200 bg-slate-50">
        <div class="flex flex-col">
          <text class="text-lg font-semibold text-slate-900">BEAM Control Room</text>
          <text class="text-sm text-slate-500">{runtime_identity(assigns)}</text>
        </div>
        <div class="flex items-center gap-3">
          <text class="text-sm text-slate-500">Sampled {assigns.sampled_at}</text>
          <UI.button id="toggle-pause" label={if(assigns.paused, do: "Resume", else: "Pause")} variant={if(assigns.paused, do: "primary", else: "default")} size="sm" phx-click="toggle-pause" />
        </div>
      </div>

      <div class="flex items-center gap-5 px-4 py-2 border-b border-slate-200">
        {stat("Processes", length(assigns.processes))}
        {stat("Memory", format_bytes(assigns.memory.total))}
        {stat("Run queue", "#{assigns.run_queue} / #{assigns.schedulers}")}
        {stat("ETS", length(assigns.tables))}
        {stat("Ports", assigns.ports)}
        <div class="flex grow" />
        <text class={if(assigns.paused, do: "text-sm text-amber-700", else: "text-sm text-green-700")}>{if(assigns.paused, do: "PAUSED", else: "LIVE")}</text>
      </div>

      <div class="flex grow min-h-0">
        <div class="flex grow min-w-0 min-h-0 flex-col border-r border-slate-200">
          <div class="flex items-end justify-between gap-4 px-4 py-3">
            <div class="flex flex-col">
              <text class="font-semibold text-slate-900">Processes</text>
              <text class="text-sm text-slate-500">Memory, mailbox pressure, and current execution</text>
            </div>
            <div class="w-[320px]">
              <UI.input id="process-filter" label="Filter processes" value={assigns.query} placeholder="PID, name, or function" cleanable={true} phx-change="filter_changed" />
            </div>
          </div>
          {process_table(processes, assigns.selected_pid)}
        </div>

        <scroll class="flex w-[340px] min-h-0 p-4 bg-slate-50">
          <div class="flex flex-col w-full gap-5">
            {process_inspector(selected)}
            {memory_summary(assigns.memory)}
            {ets_summary(assigns.tables)}
          </div>
        </scroll>
      </div>

      <UI.status_bar id="control-room-status">
        <UI.status_item id="control-room-status-left" side="left">
          <text class="text-sm text-slate-500">{length(processes)} visible processes</text>
          <UI.separator id="control-room-status-separator" orientation="vertical" />
          <text class="text-sm text-slate-500">Largest mailbox: {largest_mailbox(assigns.processes)}</text>
        </UI.status_item>
        <UI.status_item id="control-room-status-right" side="right">
          <text class="text-sm text-slate-500">Largest ETS: {largest_table(assigns.tables)}</text>
        </UI.status_item>
      </UI.status_bar>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("toggle-pause", _event, assigns), do: {:noreply, %{assigns | paused: not assigns.paused}}
  def handle_event("filter_changed", %{value: query}, assigns), do: {:noreply, %{assigns | query: query}}
  def handle_event("process_selected", %{value: pid}, assigns), do: {:noreply, %{assigns | selected_pid: pid}}

  @impl GPUI.View
  def handle_info({:control_room_snapshot, _snapshot}, %{paused: true} = assigns), do: {:noreply, assigns}

  def handle_info({:control_room_snapshot, snapshot}, assigns) do
    selected_pid = if Enum.any?(snapshot.processes, &(&1.pid == assigns.selected_pid)), do: assigns.selected_pid
    {:noreply, assigns |> Map.merge(snapshot) |> Map.put(:selected_pid, selected_pid)}
  end

  defp stat(label, value) do
    assigns = %{label: label, value: value}
    ~GPUI"""
    <div class="flex items-baseline gap-2"><text class="text-sm text-slate-500">{assigns.label}</text><text class="font-semibold text-slate-900">{assigns.value}</text></div>
    """
  end

  defp process_table([], _selected) do
    ~GPUI"""
    <div class="flex grow items-center justify-center"><text class="text-slate-500">No matching processes</text></div>
    """
  end

  defp process_table(processes, selected) do
    columns = [
      UI.table_column(%{id: "process", label: "PID", width: 130}),
      UI.table_column(%{id: "name", label: "Name / current function", width: 340}),
      UI.table_column(%{id: "memory", label: "Memory", width: 110, align: "right"}),
      UI.table_column(%{id: "mailbox", label: "Mailbox", width: 90, align: "right"}),
      UI.table_column(%{id: "reductions", label: "Reductions", width: 130, align: "right"})
    ]

    rows = Enum.map(processes, fn process ->
      UI.table_row(%{id: process.pid, children: [process.pid, process.name <> " · " <> process.current_function, format_bytes(process.memory), Integer.to_string(process.message_queue_len), format_integer(process.reductions)]})
    end)

    UI.data_table(%{id: "control-room-processes", label: "Processes", selected: selected, reveal: selected, item_height: 34, header_height: 30, "phx-change": "process_selected", class: "grow", children: columns ++ rows})
  end

  defp process_inspector(nil) do
    ~GPUI"""
    <div class="flex flex-col gap-2"><text class="font-semibold text-slate-900">Process inspector</text><text class="text-sm text-slate-500">Select a process to inspect status, current function, memory, and mailbox length.</text></div>
    """
  end

  defp process_inspector(process) do
    assigns = %{process: process}
    ~GPUI"""
    <div class="flex flex-col gap-3"><div class="flex flex-col"><text class="font-semibold text-slate-900">{assigns.process.pid}</text><text class="text-sm text-blue-600">{assigns.process.name}</text></div>{detail("Status", assigns.process.status)}{detail("Current function", assigns.process.current_function)}{detail("Initial call", assigns.process.initial_call)}{detail("Memory", format_bytes(assigns.process.memory))}{detail("Mailbox", assigns.process.message_queue_len)}</div>
    """
  end

  defp memory_summary(memory) do
    assigns = %{memory: memory}
    ~GPUI"""
    <div class="flex flex-col gap-2 border-t border-slate-200 pt-4"><text class="font-semibold text-slate-900">Memory</text>{detail("Processes", format_bytes(assigns.memory.processes))}{detail("Binary", format_bytes(assigns.memory.binary))}{detail("ETS", format_bytes(assigns.memory.ets))}{detail("Code", format_bytes(assigns.memory.code))}</div>
    """
  end

  defp ets_summary(tables) do
    assigns = %{tables: tables |> Enum.sort_by(& &1.memory, :desc) |> Enum.take(6)}
    ~GPUI"""
    <div class="flex flex-col gap-2 border-t border-slate-200 pt-4"><text class="font-semibold text-slate-900">ETS ownership</text>{Enum.map(assigns.tables, &ets_row/1)}</div>
    """
  end

  defp ets_row(table) do
    assigns = %{table: table}
    ~GPUI"""
    <div class="flex flex-col py-1"><div class="flex justify-between gap-3"><text class="text-sm text-slate-900">{assigns.table.name}</text><text class="text-sm text-slate-500">{assigns.table.size} objects</text></div><text class="text-sm text-slate-500">Owner {assigns.table.owner} · {assigns.table.memory} words</text></div>
    """
  end

  defp detail(label, value) do
    assigns = %{label: label, value: value}
    ~GPUI"""
    <div class="flex flex-col gap-1"><text class="text-sm text-slate-500">{assigns.label}</text><text class="text-sm text-slate-900">{assigns.value}</text></div>
    """
  end

  defp filtered_processes(assigns) do
    query = assigns.query |> String.trim() |> String.downcase()
    assigns.processes |> Enum.sort_by(& &1.memory, :desc) |> Enum.take(200) |> Enum.filter(fn process -> query == "" or Enum.any?([process.pid, process.name, process.current_function], &String.contains?(String.downcase(&1), query)) end)
  end

  defp runtime_identity(assigns), do: "#{length(assigns.processes)} processes · #{assigns.schedulers} schedulers · supervised sampler"
  defp largest_mailbox([]), do: "0 messages"
  defp largest_mailbox(processes), do: "#{Enum.max_by(processes, & &1.message_queue_len).message_queue_len} messages"
  defp largest_table([]), do: "None"
  defp largest_table(tables), do: Enum.max_by(tables, & &1.memory).name

  defp format_bytes(bytes) when bytes >= 1_048_576, do: :erlang.float_to_binary(bytes / 1_048_576, decimals: 1) <> " MB"
  defp format_bytes(bytes) when bytes >= 1_024, do: :erlang.float_to_binary(bytes / 1_024, decimals: 1) <> " KB"
  defp format_bytes(bytes), do: "#{bytes} B"
  defp format_integer(value), do: value |> Integer.to_string() |> String.reverse() |> String.graphemes() |> Enum.chunk_every(3) |> Enum.map_join(",", &Enum.join/1) |> String.reverse()
end

defmodule Examples.BeamControlRoom.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    snapshot = args |> Map.new() |> Map.get_lazy(:snapshot, &Examples.BeamControlRoom.Sampler.snapshot/0)

    {:ok,
     [
       window "BEAM Control Room" do
         size(1320, 820)
         root(Examples.BeamControlRoom.View, Map.merge(snapshot, %{paused: false, query: "", selected_pid: nil}))
       end
     ]}
  end
end
