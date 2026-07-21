Code.require_file("event.exs", __DIR__)

defmodule Examples.LogTraceExplorer.LoggerHandler do
  @moduledoc false

  def adding_handler(config), do: {:ok, config}
  def removing_handler(_config), do: :ok
  def changing_config(_set_or_update, _old_config, new_config), do: {:ok, new_config}

  def log(event, %{config: %{receiver: receiver}}) do
    send(receiver, {:logger_event, event})
  end
end

defmodule Examples.LogTraceExplorer.View do
  use GPUI.View

  alias Examples.LogTraceExplorer.Event
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    selected = if is_integer(assigns.selected_index), do: assigns.selected_id
    reveal = if is_integer(assigns.reveal_index), do: assigns.reveal_id

    ~GPUI"""
    <div class="flex flex-col w-[1200px] h-[760px] bg-slate-900">
      <div class="flex flex-col gap-3 p-4" style={[background: {:rgb, 0x1E293B}]}>
        <div class="flex items-center justify-between gap-4">
          <div class="flex flex-col gap-1">
            <text class="text-white text-2xl font-semibold">OTP log and trace explorer</text>
            <text style={[color: {:rgb, 0x94A3B8}]}>{summary(assigns)}</text>
          </div>
          <div class="flex gap-2">
            <UI.button
              id="pause-events"
              label={pause_label(assigns.paused)}
              variant={if(assigns.paused, do: "primary", else: "default")}
              phx-click="toggle_pause"
            />
            <UI.button
              id="clear-events"
              label="Clear"
              disabled={assigns.retained_count == 0}
              phx-click="clear_events"
            />
          </div>
        </div>
        <div class="flex items-center gap-3">
          <UI.input
            id="event-filter"
            label="Event filter"
            value={assigns.query}
            placeholder="Filter messages, sources, levels, or metadata"
            cleanable={true}
            phx-change="filter_changed"
          />
          <UI.select
            id="level-filter"
            label="Log level"
            value={assigns.level}
            options={level_options()}
            phx-change="level_changed"
          />
          <UI.switch
            id="follow-tail"
            label="Follow tail"
            checked={assigns.follow}
            phx-change="follow_changed"
          />
        </div>
      </div>

      <div class="flex h-[600px]">
        <div class="flex flex-col w-[820px] h-[600px]" style={[background: {:rgb, 0x0F172A}]}>
          {event_collection(assigns, selected, reveal)}
        </div>

        <div class="flex flex-col w-[380px] h-[600px] gap-3 p-5" style={[background: {:rgb, 0x111827}]}>
          {details(assigns.selected_event, assigns.copy_count)}
        </div>
      </div>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("filter_changed", %{value: query}, assigns),
    do: begin_filter(assigns, :query, String.slice(query, 0, 256))

  def handle_event("level_changed", %{value: level}, assigns),
    do: begin_filter(assigns, :level, level)

  def handle_event("events_range_changed", %{value: range}, assigns),
    do: {:noreply, %{assigns | range: range, generation: assigns.generation + 1}}

  def handle_event("event_selected", %{value: selected_id}, assigns) do
    case Enum.find_index(assigns.events, &(&1.id == selected_id)) do
      nil ->
        {:noreply, assigns}

      local_index ->
        selected_index = assigns.offset + local_index

        {:noreply,
         %{
           assigns
           | selected_id: selected_id,
             selected_index: selected_index,
             reveal_id: selected_id,
             reveal_index: selected_index,
             selected_event: Enum.at(assigns.events, local_index),
             follow: false,
             copy_count: 0,
             generation: assigns.generation + 1
         }}
    end
  end

  def handle_event("toggle_pause", _event, assigns),
    do: {:noreply, %{assigns | paused: not assigns.paused}}

  def handle_event("follow_changed", %{value: follow}, assigns) do
    assigns =
      if follow do
        %{
          assigns
          | follow: true,
            selected_id: nil,
            selected_index: nil,
            selected_event: nil,
            reveal_id: nil,
            reveal_index: nil,
            copy_count: 0,
            generation: assigns.generation + 1
        }
      else
        %{assigns | follow: false, generation: assigns.generation + 1}
      end

    {:noreply, assigns}
  end

  def handle_event("clear_events", _event, assigns) do
    {:noreply,
     %{
       assigns
       | events: [],
         total_count: 0,
         offset: 0,
         max_columns: 0,
         selected_id: nil,
         selected_index: nil,
         selected_event: nil,
         reveal_id: nil,
         reveal_index: nil,
         retained_count: 0,
         dropped_count: 0,
         copy_count: 0,
         range: Examples.LogTraceExplorer.Model.initial_range(),
         generation: assigns.generation + 1,
         filter_status: :ready
     }}
  end

  def handle_event("event_message_copied", _event, assigns),
    do: {:noreply, %{assigns | copy_count: assigns.copy_count + 1}}

  @impl GPUI.View
  def handle_info(
        {:events_slice, generation, slice, retained_count, dropped_count},
        %{generation: generation} = assigns
      ) do
    {:noreply,
     %{
       assigns
       | events: slice.events,
         total_count: slice.total,
         offset: slice.offset,
         max_columns: slice.max_columns,
         selected_id: slice.selected_id,
         selected_index: slice.selected_index,
         selected_event: slice.selected_event,
         reveal_id: slice.reveal_id,
         reveal_index: slice.reveal_index,
         retained_count: retained_count,
         dropped_count: dropped_count,
         filter_status: :ready
     }}
  end

  def handle_info({:events_slice, _generation, _slice, _retained, _dropped}, assigns),
    do: {:noreply, assigns}

  def handle_info({:filter_failed, generation, message}, %{generation: generation} = assigns),
    do: {:noreply, %{assigns | filter_status: {:error, message}}}

  def handle_info({:filter_failed, _generation, _message}, assigns), do: {:noreply, assigns}
  def handle_info(_message, assigns), do: {:noreply, assigns}

  defp begin_filter(assigns, field, value) do
    {:noreply,
     assigns
     |> Map.put(field, value)
     |> Map.merge(%{
       selected_id: nil,
       selected_index: nil,
       selected_event: nil,
       reveal_id: nil,
       reveal_index: nil,
       copy_count: 0,
       range: Examples.LogTraceExplorer.Model.initial_range(),
       generation: assigns.generation + 1,
       filter_status: :filtering
     })}
  end

  defp event_collection(%{total_count: 0, filter_status: :ready} = assigns, _selected, _reveal) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center h-[600px] gap-2 p-6">
      <text class="text-white text-lg">{empty_title(assigns)}</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>{empty_message(assigns)}</text>
    </div>
    """
  end

  defp event_collection(assigns, selected, reveal) do
    collection_assigns = %{assigns: assigns, selected: selected, reveal: reveal}

    ~GPUI"""
    <UI.code_viewer
      id="log-events"
      label="OTP log events"
      mode="plain"
      total_count={collection_assigns.assigns.total_count}
      offset={collection_assigns.assigns.offset}
      overscan={12}
      item_height={25}
      max_columns={collection_assigns.assigns.max_columns}
      selected={collection_assigns.selected}
      selected_index={collection_assigns.assigns.selected_index}
      reveal={collection_assigns.reveal}
      reveal_index={collection_assigns.assigns.reveal_index}
      phx-change="event_selected"
      phx-range="events_range_changed"
      class="h-[600px]"
    >
      {Enum.map(collection_assigns.assigns.events, &event_line/1)}
    </UI.code_viewer>
    """
  end

  defp empty_title(%{retained_count: 0}), do: "No events retained"
  defp empty_title(_assigns), do: "No matching events"

  defp empty_message(%{retained_count: 0}),
    do: "Logger events will appear here as they arrive."

  defp empty_message(_assigns), do: "Adjust the level or text filter to widen the result."

  defp event_line(event) do
    UI.code_line(%{
      id: event.id,
      number: event.sequence,
      text: Event.row_text(event),
      kind: event.level
    })
  end

  defp details(nil, _copy_count) do
    ~GPUI"""
    <div class="flex flex-col gap-3">
      <text class="text-white text-xl font-semibold">Event details</text>
      <text style={[color: {:rgb, 0x94A3B8}]}>Select a retained event to inspect its message and metadata.</text>
    </div>
    """
  end

  defp details(event, copy_count) do
    detail_lines = Event.detail_lines(event)

    assigns = %{
      event: event,
      copy_count: copy_count,
      detail_lines: detail_lines,
      max_columns:
        Enum.reduce(detail_lines, 0, fn line, columns -> max(columns, String.length(line)) end)
    }

    ~GPUI"""
    <div class="flex flex-col gap-3">
      <div class="flex items-center justify-between gap-2">
        <text class="text-white text-xl font-semibold">Event {assigns.event.sequence}</text>
        <text style={[color: level_color(assigns.event.level)]}>{String.upcase(assigns.event.level)}</text>
      </div>
      <text style={[color: {:rgb, 0x94A3B8}]}>{assigns.event.timestamp} · {assigns.event.source}</text>
      <UI.code_viewer
        id="selected-event-details"
        label="Selected event message and metadata"
        mode="plain"
        item_height={23}
        max_columns={assigns.max_columns}
        show_line_numbers={false}
        class="h-[390px]"
      >
        {Enum.map(Enum.with_index(assigns.detail_lines), &detail_line(&1, assigns.event.level))}
      </UI.code_viewer>
      <div class="flex items-center gap-2">
        <UI.copy_button
          id="copy-event-message"
          label="Copy message"
          text={assigns.event.message}
          phx-click="event_message_copied"
        />
        <text style={[color: {:rgb, 0x86EFAC}]}>{copied_label(assigns.copy_count)}</text>
      </div>
    </div>
    """
  end

  defp detail_line({line, index}, _level) do
    UI.code_line(%{id: "detail-#{index}", text: line, kind: "context"})
  end

  defp copied_label(count) when count > 0, do: "Copied on this display"
  defp copied_label(_count), do: ""

  defp summary(%{filter_status: :filtering} = assigns),
    do: "Filtering #{assigns.retained_count} retained events…"

  defp summary(%{filter_status: {:error, message}}), do: "Filter failed: #{message}"

  defp summary(assigns) do
    activity = if assigns.paused, do: "view paused", else: "live"

    "#{assigns.total_count} matching · #{assigns.retained_count} retained · " <>
      "#{assigns.dropped_count} dropped · #{activity}"
  end

  defp pause_label(true), do: "Resume view"
  defp pause_label(false), do: "Pause view"

  defp level_options do
    [
      {"All levels", "all"},
      {"Debug", "debug"},
      {"Info", "info"},
      {"Warning", "warning"},
      {"Error", "error"}
    ]
  end

  defp level_color("debug"), do: {:rgb, 0x94A3B8}
  defp level_color("warning"), do: {:rgb, 0xFBBF24}
  defp level_color("error"), do: {:rgb, 0xFCA5A5}
  defp level_color(_level), do: {:rgb, 0x7DD3FC}
end

defmodule Examples.LogTraceExplorer.App do
  use GPUI.Application

  alias Examples.LogTraceExplorer.Model

  @impl GPUI.Application
  def mount(args) do
    args = Map.new(args)
    events = args |> Map.get(:events, []) |> Model.prepare()
    range = Model.initial_range()

    base = %{
      range: range,
      follow: Map.get(args, :follow, true),
      selected_id: nil
    }

    filtered = Model.filter(events, "", "all")
    slice = Model.snapshot(filtered, base)

    {:ok,
     [
       window "OTP Log and Trace Explorer" do
         size(1200, 760)

         root(Examples.LogTraceExplorer.View,
           query: "",
           level: "all",
           paused: false,
           follow: base.follow,
           filter_status: :ready,
           generation: 0,
           range: range,
           events: slice.events,
           total_count: slice.total,
           offset: slice.offset,
           max_columns: slice.max_columns,
           selected_id: slice.selected_id,
           selected_index: slice.selected_index,
           selected_event: slice.selected_event,
           reveal_id: slice.reveal_id,
           reveal_index: slice.reveal_index,
           retained_count: length(events),
           dropped_count: 0,
           copy_count: 0
         )
       end
     ]}
  end
end

defmodule Examples.LogTraceExplorer.Source do
  use GenServer

  alias Examples.LogTraceExplorer.Event
  alias Examples.LogTraceExplorer.LoggerHandler
  alias Examples.LogTraceExplorer.Model
  alias GPUI.Runtime
  alias GPUI.Runtime.Update

  @control_events ~w(events_range_changed event_selected toggle_pause follow_changed)
  @filter_events ~w(filter_changed level_changed)

  def start_link(opts) do
    {gen_server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  def append(source, event), do: GenServer.call(source, {:append, event})
  def retained_count(source), do: GenServer.call(source, :retained_count)

  @impl GenServer
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    :ok = Runtime.subscribe(runtime)

    capacity = opts |> Keyword.get(:capacity, 10_000) |> max(1) |> min(100_000)
    initial_events = Keyword.get(opts, :events, [])

    state = %{
      runtime: runtime,
      runtime_pid: GenServer.whereis(runtime) || runtime,
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      filter_fun: Keyword.get(opts, :filter, &Model.filter/3),
      owner: Keyword.get(opts, :owner),
      capacity: capacity,
      events: :queue.new(),
      event_count: 0,
      filtered: :queue.new(),
      next_sequence: 1,
      revision: 0,
      dropped_count: 0,
      criteria: {"", "all"},
      paused: false,
      publish_scheduled: false,
      filter_task: nil,
      logger_handler_id: nil
    }

    state = Enum.reduce(initial_events, state, &append_input(&2, &1, false))

    with {:ok, state} <- maybe_attach_logger(state, opts) do
      send(self(), :initial_filter)
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_call({:append, input}, _from, state) do
    state = append_input(state, input, true)
    {:reply, {:ok, state.next_sequence - 1}, state}
  end

  def handle_call(:retained_count, _from, state), do: {:reply, state.event_count, state}

  @impl GenServer
  def handle_info(:initial_filter, state) do
    assigns = state.runtime |> Runtime.snapshot() |> root_assigns()
    {:noreply, start_filter(state, assigns)}
  end

  def handle_info({:logger_event, logger_event}, state) do
    event = Event.from_logger(logger_event, state.next_sequence)
    {:noreply, append_normalized(state, event, true)}
  end

  def handle_info(:publish, state), do: {:noreply, publish(%{state | publish_scheduled: false})}

  def handle_info({:gpui, runtime, %Update{} = update}, %{runtime_pid: runtime} = state) do
    event_names = Enum.map(update.events, & &1.event)

    state =
      cond do
        "clear_events" in event_names ->
          notify(state.owner, {:log_trace_explorer, :controls, event_names})

          state
          |> cancel_filter()
          |> clear_events()
          |> schedule_publish()

        Enum.any?(event_names, &(&1 in @filter_events)) ->
          notify(state.owner, {:log_trace_explorer, :controls, event_names})
          start_filter(state, root_assigns(update.snapshot))

        Enum.any?(event_names, &(&1 in @control_events)) ->
          notify(state.owner, {:log_trace_explorer, :controls, event_names})
          assigns = root_assigns(update.snapshot)
          state = %{state | paused: assigns.paused}

          if state.filter_task do
            state
          else
            schedule_publish(state)
          end

        true ->
          state
      end

    {:noreply, state}
  end

  def handle_info({ref, filtered}, %{filter_task: %{task: %Task{ref: ref}}} = state) do
    Process.demonitor(ref, [:flush])
    task = state.filter_task
    state = %{state | filter_task: nil}

    if task.revision == state.revision do
      filtered = :queue.from_list(filtered)

      {:noreply,
       state
       |> Map.put(:filtered, filtered)
       |> schedule_publish()}
    else
      assigns = state.runtime |> Runtime.snapshot() |> root_assigns()
      {:noreply, start_filter(state, assigns)}
    end
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{filter_task: %{task: %Task{ref: ref}}} = state
      ) do
    generation = state.runtime |> Runtime.snapshot() |> root_assigns() |> Map.fetch!(:generation)
    message = "#{inspect(reason)}"
    {:ok, _snapshot} = Runtime.send_view(state.runtime, 1, {:filter_failed, generation, message})
    notify(state.owner, {:log_trace_explorer, :filter_failed, message})
    {:noreply, %{state | filter_task: nil}}
  end

  def handle_info({ref, _result}, state) when is_reference(ref), do: {:noreply, state}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %{logger_handler_id: nil}), do: :ok

  def terminate(_reason, %{logger_handler_id: handler_id}) do
    _result = :logger.remove_handler(handler_id)
    :ok
  end

  defp append_input(state, input, publish?) do
    event = Event.from_input(input, state.next_sequence)
    append_normalized(state, event, publish?)
  end

  defp append_normalized(state, event, publish?) do
    events = :queue.in(event, state.events)

    state = %{
      state
      | events: events,
        event_count: state.event_count + 1,
        next_sequence: state.next_sequence + 1,
        revision: state.revision + 1
    }

    {state, dropped_event} = trim_retention(state)
    state = update_incremental_filter(state, event, dropped_event)
    notify(state.owner, {:log_trace_explorer, :ingested, event.id})

    if publish? and not state.paused and is_nil(state.filter_task),
      do: schedule_publish(state),
      else: state
  end

  defp trim_retention(%{event_count: count, capacity: capacity} = state) when count <= capacity,
    do: {state, nil}

  defp trim_retention(state) do
    {{:value, dropped}, events} = :queue.out(state.events)

    {%{
       state
       | events: events,
         event_count: state.event_count - 1,
         dropped_count: state.dropped_count + 1
     }, dropped}
  end

  defp update_incremental_filter(%{filter_task: task} = state, _event, _dropped)
       when not is_nil(task),
       do: state

  defp update_incremental_filter(state, event, dropped) do
    {query, level} = state.criteria

    filtered =
      if Model.matches?(event, query, level),
        do: :queue.in(event, state.filtered),
        else: state.filtered

    filtered =
      if dropped && Model.matches?(dropped, query, level) do
        case :queue.out(filtered) do
          {{:value, %{id: id}}, rest} when id == dropped.id -> rest
          _other -> filtered
        end
      else
        filtered
      end

    %{state | filtered: filtered}
  end

  defp start_filter(state, assigns) do
    state = cancel_filter(state)
    query = assigns.query |> String.slice(0, 256) |> String.trim() |> String.downcase()
    level = assigns.level
    events = :queue.to_list(state.events)
    filter_fun = state.filter_fun
    revision = state.revision

    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        filter_fun.(events, query, level)
      end)

    %{
      state
      | criteria: {query, level},
        paused: assigns.paused,
        filter_task: %{task: task, revision: revision}
    }
  end

  defp cancel_filter(%{filter_task: nil} = state), do: state

  defp cancel_filter(%{filter_task: %{task: task}} = state) do
    _result = Task.Supervisor.terminate_child(state.task_supervisor, task.pid)
    %{state | filter_task: nil}
  end

  defp clear_events(state) do
    %{
      state
      | events: :queue.new(),
        event_count: 0,
        filtered: :queue.new(),
        dropped_count: 0,
        revision: state.revision + 1
    }
  end

  defp schedule_publish(%{publish_scheduled: true} = state), do: state

  defp schedule_publish(state) do
    send(self(), :publish)
    %{state | publish_scheduled: true}
  end

  defp publish(%{filter_task: task} = state) when not is_nil(task), do: state

  defp publish(state) do
    assigns = state.runtime |> Runtime.snapshot() |> root_assigns()
    filtered = :queue.to_list(state.filtered)
    slice = Model.snapshot(filtered, assigns)

    {:ok, _snapshot} =
      Runtime.send_view(
        state.runtime,
        1,
        {:events_slice, assigns.generation, slice, state.event_count, state.dropped_count}
      )

    notify(
      state.owner,
      {:log_trace_explorer, :published, assigns.generation, slice.total, length(slice.events),
       state.revision}
    )

    state
  end

  defp maybe_attach_logger(state, opts) do
    if Keyword.get(opts, :attach_logger, false) do
      handler_id = Keyword.get(opts, :handler_id, :gpui_log_trace_explorer)

      case :logger.add_handler(handler_id, LoggerHandler, %{config: %{receiver: self()}}) do
        :ok -> {:ok, %{state | logger_handler_id: handler_id}}
        {:error, reason} -> {:stop, {:logger_handler_failed, reason}}
      end
    else
      {:ok, state}
    end
  end

  defp root_assigns(%GPUI.Snapshot{windows: [%{root: %{assigns: assigns}} | _windows]}),
    do: assigns

  defp notify(nil, _message), do: :ok
  defp notify(owner, message), do: send(owner, message)
end

defmodule Examples.LogTraceExplorer.DemoProducer do
  use GenServer

  require Logger

  @events [
    {:debug, "Cache lookup completed", [component: :cache, cache: :users, hit: true]},
    {:info, "HTTP request completed",
     [component: :web, method: "GET", path: "/api/users", status: 200]},
    {:warning, "Job retry scheduled", [component: :jobs, queue: :exports, attempt: 2]},
    {:error, "Export failed\nconnection closed by peer", [component: :exports, retryable: true]}
  ]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    state = %{interval: Keyword.get(opts, :interval, 1_500), index: 0}
    send(self(), :emit)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:emit, state) do
    {level, message, metadata} = Enum.at(@events, rem(state.index, length(@events)))
    Logger.log(level, message, metadata)
    Process.send_after(self(), :emit, state.interval)
    {:noreply, %{state | index: state.index + 1}}
  end
end

defmodule Examples.LogTraceExplorer.Supervisor do
  use Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  @impl Supervisor
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    task_supervisor = Module.concat(__MODULE__, TaskSupervisor)

    children = [
      {Task.Supervisor, name: task_supervisor},
      {Examples.LogTraceExplorer.Source,
       name: Keyword.get(opts, :source_name, Examples.LogTraceExplorer.Source),
       runtime: runtime,
       task_supervisor: task_supervisor,
       capacity: Keyword.get(opts, :capacity, 10_000),
       attach_logger: Keyword.get(opts, :attach_logger, true),
       events: Keyword.get(opts, :events, []),
       owner: Keyword.get(opts, :owner)}
    ]

    children =
      if Keyword.get(opts, :demo, true) do
        children ++
          [
            {Examples.LogTraceExplorer.DemoProducer,
             interval: Keyword.get(opts, :demo_interval, 1_500)}
          ]
      else
        children
      end

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
