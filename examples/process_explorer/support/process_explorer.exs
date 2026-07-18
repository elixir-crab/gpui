defmodule Examples.ProcessExplorer.View do
  use GPUI.View

  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    processes = visible_processes(assigns)
    selected = selected_process(assigns)
    visible_selection = visible_selection(processes, assigns.selected_pid)

    ~GPUI"""
    <div class="flex flex-col w-[1100px] h-[720px] bg-slate-900">
      <div class="flex flex-col gap-3 p-4" style={[background: {:rgb, 0x1E293B}]}>
        <div class="flex items-center justify-between gap-4">
          <div class="flex flex-col">
            <text class="text-white text-2xl font-semibold">BEAM process explorer</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>{summary(assigns.processes, processes, assigns.paused)}</text>
          </div>
          <UI.button
            id="pause-updates"
            label={pause_label(assigns.paused)}
            variant={pause_variant(assigns.paused)}
            phx-click="toggle_pause"
          />
        </div>
        <div class="flex gap-3">
          <UI.input
            id="process-filter"
            value={assigns.filter}
            placeholder="Filter processes by PID, name, or function"
            cleanable={true}
            phx-change="filter_changed"
          />
          <UI.select
            id="process-sort"
            value={assigns.sort}
            options={sort_options()}
            phx-change="sort_changed"
          />
        </div>
      </div>

      <div class="flex h-[570px]">
        <div class="flex flex-col w-[720px] h-[570px]">
          {process_collection(processes, visible_selection, assigns)}
        </div>

        <div class="flex flex-col w-[380px] h-[570px] gap-3 p-5" style={[background: {:rgb, 0x111827}]}>
          {inspector(selected, not is_nil(selected) and is_nil(visible_selection))}
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("filter_changed", %{value: filter}, assigns),
    do: {:noreply, %{assigns | filter: filter}}

  def handle_event("sort_changed", %{value: sort}, assigns),
    do: {:noreply, %{assigns | sort: sort}}

  def handle_event("process_sorted", %{value: sort}, assigns),
    do: {:noreply, %{assigns | sort: sort}}

  def handle_event("toggle_pause", _event, assigns),
    do: {:noreply, %{assigns | paused: not assigns.paused}}

  def handle_event("process_selected", %{value: pid}, assigns),
    do: {:noreply, %{assigns | selected_pid: pid}}

  @impl GPUI.View
  def handle_info({:process_snapshot, _processes}, %{paused: true} = assigns),
    do: {:noreply, assigns}

  def handle_info({:process_snapshot, processes}, assigns) do
    selected_pid = retain_selection(assigns.selected_pid, processes)
    {:noreply, %{assigns | processes: processes, selected_pid: selected_pid}}
  end

  defp visible_processes(assigns) do
    filter = assigns.filter |> String.trim() |> String.downcase()

    assigns.processes
    |> Enum.filter(&matches_filter?(&1, filter))
    |> sort_processes(assigns.sort)
  end

  defp matches_filter?(_process, ""), do: true

  defp matches_filter?(process, filter) do
    Enum.any?([process.pid, process.name, process.current_function], fn value ->
      value |> String.downcase() |> String.contains?(filter)
    end)
  end

  defp sort_processes(processes, "name"), do: Enum.sort_by(processes, & &1.name)

  defp sort_processes(processes, sort) when sort in ["memory", "mailbox", "reductions"],
    do: Enum.sort_by(processes, &sort_key(&1, sort), :desc)

  defp sort_processes(processes, _sort), do: sort_processes(processes, "memory")

  defp sort_key(process, "memory"), do: process.memory
  defp sort_key(process, "mailbox"), do: process.message_queue_len
  defp sort_key(process, "reductions"), do: process.reductions

  defp selected_process(%{selected_pid: nil}), do: nil

  defp selected_process(assigns),
    do: Enum.find(assigns.processes, &(&1.pid == assigns.selected_pid))

  defp visible_selection(_processes, nil), do: nil

  defp visible_selection(processes, selected_pid) do
    if Enum.any?(processes, &(&1.pid == selected_pid)), do: selected_pid
  end

  defp retain_selection(nil, _processes), do: nil

  defp retain_selection(pid, processes) do
    if Enum.any?(processes, &(&1.pid == pid)), do: pid, else: nil
  end

  defp process_row(process) do
    UI.table_row(%{
      id: process.pid,
      children: [
        process.pid,
        process_name_cell(process),
        format_bytes(process.memory),
        Integer.to_string(process.message_queue_len),
        format_integer(process.reductions)
      ]
    })
  end

  defp process_name_cell(process) do
    assigns = %{process: process}

    ~GPUI"""
    <div class="flex flex-col">
      <text class="text-white">{assigns.process.name}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.process.current_function}</text>
    </div>
    """
  end

  defp process_collection([], _visible_selection, assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center h-[520px] gap-2 p-6">
      <text class="text-white text-lg">{empty_title(assigns)}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{empty_message(assigns)}</text>
    </div>
    """
  end

  defp process_collection(processes, visible_selection, assigns) do
    table_assigns = %{
      processes: processes,
      visible_selection: visible_selection,
      sort: assigns.sort
    }

    ~GPUI"""
    <UI.data_table
      id="processes"
      label="BEAM processes"
      selected={table_assigns.visible_selection}
      reveal={table_assigns.visible_selection}
      sort_column={table_assigns.sort}
      sort_direction={sort_direction(table_assigns.sort)}
      item_height={76}
      header_height={50}
      phx-change="process_selected"
      phx-sort="process_sorted"
      class="h-[570px]"
    >
      {process_columns() ++ Enum.map(table_assigns.processes, &process_row/1)}
    </UI.data_table>
    """
  end

  defp process_columns do
    [
      UI.table_column(%{id: "pid", label: "Process", width: 130}),
      UI.table_column(%{id: "name", label: "Name / function", width: 210, sortable: true}),
      UI.table_column(%{
        id: "memory",
        label: "Memory",
        width: 115,
        align: "right",
        sortable: true
      }),
      UI.table_column(%{
        id: "mailbox",
        label: "Mailbox",
        width: 115,
        align: "right",
        sortable: true
      }),
      UI.table_column(%{
        id: "reductions",
        label: "Reductions",
        width: 130,
        align: "right",
        sortable: true
      })
    ]
  end

  defp sort_direction("name"), do: "ascending"
  defp sort_direction(_sort), do: "descending"

  defp inspector(nil, _hidden) do
    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">Process details</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Select a process to inspect its runtime state.</text>
    </div>
    """
  end

  defp inspector(process, hidden) do
    assigns = %{process: process, hidden: hidden}

    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">{assigns.process.pid}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.process.name}</text>
      {hidden_selection_notice(assigns.hidden)}
      {detail("Status", assigns.process.status)}
      {detail("Current function", assigns.process.current_function)}
      {detail("Initial call", assigns.process.initial_call)}
      {detail("Memory", format_bytes(assigns.process.memory))}
      {detail("Mailbox", Integer.to_string(assigns.process.message_queue_len))}
      {detail("Reductions", format_integer(assigns.process.reductions))}
    </div>
    """
  end

  defp detail(label, value) do
    assigns = %{label: label, value: value}

    ~GPUI"""
    <div class="flex flex-col gap-1">
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.label}</text>
      <text class="text-white">{assigns.value}</text>
    </div>
    """
  end

  defp hidden_selection_notice(true) do
    ~GPUI"""
    <text style={[color: {:rgb, 0xFBBF24}]}>Hidden by the current filter</text>
    """
  end

  defp hidden_selection_notice(false) do
    ~GPUI"""
    <div />
    """
  end

  defp empty_title(assigns) do
    if String.trim(assigns.filter) == "",
      do: "No processes available",
      else: "No matching processes"
  end

  defp empty_message(assigns) do
    if String.trim(assigns.filter) == "",
      do: "The next sampler update will appear here.",
      else: "Try a different PID, name, or function."
  end

  defp pause_label(true), do: "Resume updates"
  defp pause_label(false), do: "Pause updates"
  defp pause_variant(true), do: "primary"
  defp pause_variant(false), do: "default"

  defp summary(processes, visible, paused) do
    count = length(processes)
    visible_count = length(visible)
    memory = Enum.reduce(processes, 0, &(&1.memory + &2))

    scope =
      if visible_count == count,
        do: "#{count} processes",
        else: "#{visible_count} of #{count} processes"

    update_state = if paused, do: "updates paused", else: "live updates"

    "#{scope} · #{format_bytes(memory)} total process memory · #{update_state}"
  end

  defp sort_options do
    [
      {"Memory", "memory"},
      {"Mailbox", "mailbox"},
      {"Reductions", "reductions"},
      {"Registered name", "name"}
    ]
  end

  defp format_bytes(bytes) when bytes >= 1_048_576,
    do: :erlang.float_to_binary(bytes / 1_048_576, decimals: 1) <> " MB"

  defp format_bytes(bytes) when bytes >= 1_024,
    do: :erlang.float_to_binary(bytes / 1_024, decimals: 1) <> " KB"

  defp format_bytes(bytes), do: "#{bytes} B"
  defp format_integer(value), do: value |> Integer.to_string() |> add_separators()

  defp add_separators(value) do
    value
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end

defmodule Examples.ProcessExplorer.App do
  use GPUI.Application

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    processes = Map.get_lazy(args, :processes, &Examples.ProcessExplorer.Collector.collect/0)

    {:ok,
     [
       window "BEAM Process Explorer" do
         size(1100, 720)

         root(Examples.ProcessExplorer.View,
           processes: processes,
           selected_pid: nil,
           filter: "",
           sort: "memory",
           paused: false
         )
       end
     ]}
  end
end

defmodule Examples.ProcessExplorer.Collector do
  use GenServer

  @fields [
    :registered_name,
    :status,
    :message_queue_len,
    :memory,
    :reductions,
    :current_function,
    :initial_call
  ]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def collect do
    Process.list()
    |> Enum.flat_map(&process_row/1)
  end

  @impl GenServer
  def init(opts) do
    state = %{
      runtime: Keyword.fetch!(opts, :runtime),
      interval: Keyword.get(opts, :interval, 1_000)
    }

    send(self(), :collect)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:collect, state) do
    {:ok, _snapshot} = GPUI.Runtime.send_view(state.runtime, 1, {:process_snapshot, collect()})
    Process.send_after(self(), :collect, state.interval)
    {:noreply, state}
  end

  defp process_row(pid) do
    case Process.info(pid, @fields) do
      nil ->
        []

      info ->
        [
          %{
            pid: inspect(pid),
            name: process_name(info[:registered_name]),
            status: Atom.to_string(info[:status]),
            message_queue_len: info[:message_queue_len],
            memory: info[:memory],
            reductions: info[:reductions],
            current_function: format_mfa(info[:current_function]),
            initial_call: format_mfa(info[:initial_call])
          }
        ]
    end
  end

  defp process_name([]), do: "unregistered"
  defp process_name(name), do: Atom.to_string(name)

  defp format_mfa({module, function, arity}),
    do: "#{inspect(module)}.#{function}/#{arity}"

  defp format_mfa(other), do: inspect(other)
end
