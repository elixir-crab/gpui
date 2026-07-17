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
            <text style={[color: {:rgb, 0x94A3B8}]}>{summary(assigns.processes, assigns.paused)}</text>
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
            placeholder="Filter by PID, name, or function"
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
          <div class="flex gap-3 p-3" style={[background: {:rgb, 0x0F172A}]}>
            <text class="text-white w-[130px]">Process</text>
            <text class="text-white w-[180px]">Name / function</text>
            <text class="text-white w-[100px]">Memory</text>
            <text class="text-white w-[100px]">Mailbox</text>
            <text class="text-white w-[110px]">Reductions</text>
          </div>
          <UI.virtual_list
            id="processes"
            label="BEAM processes"
            selected={visible_selection}
            reveal={visible_selection}
            item_height={76}
            phx-change="process_selected"
            class="h-[520px]"
          >
            {Enum.map(processes, &process_row(&1, assigns.selected_pid))}
          </UI.virtual_list>
        </div>

        <div class="flex flex-col w-[380px] h-[570px] gap-3 p-5" style={[background: {:rgb, 0x111827}]}>
          {inspector(selected)}
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

  defp process_row(process, selected_pid) do
    assigns = %{process: process, selected: process.pid == selected_pid}

    ~GPUI"""
    <UI.virtual_list_item id={assigns.process.pid} style={row_style(assigns.selected)}>
      <div class="flex items-center gap-3 p-3">
        <text class="text-white w-[130px]">{assigns.process.pid}</text>
        <div class="flex flex-col w-[180px]">
          <text class="text-white">{assigns.process.name}</text>
          <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.process.current_function}</text>
        </div>
        <text class="text-white w-[100px]">{format_bytes(assigns.process.memory)}</text>
        <text class="text-white w-[100px]">{assigns.process.message_queue_len}</text>
        <text class="text-white w-[110px]">{format_integer(assigns.process.reductions)}</text>
      </div>
    </UI.virtual_list_item>
    """
  end

  defp inspector(nil) do
    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">Process details</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Select a process to inspect its runtime state.</text>
    </div>
    """
  end

  defp inspector(process) do
    assigns = %{process: process}

    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">{assigns.process.pid}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.process.name}</text>
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

  defp row_style(true), do: [background: {:rgb, 0x1D4ED8}]
  defp row_style(false), do: [background: {:rgb, 0x111827}]
  defp pause_label(true), do: "Resume updates"
  defp pause_label(false), do: "Pause updates"
  defp pause_variant(true), do: "primary"
  defp pause_variant(false), do: "default"

  defp summary(processes, true),
    do: "#{length(processes)} processes · updates paused"

  defp summary(processes, false) do
    memory = Enum.reduce(processes, 0, &(&1.memory + &2))
    "#{length(processes)} processes · #{format_bytes(memory)} total process memory"
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
