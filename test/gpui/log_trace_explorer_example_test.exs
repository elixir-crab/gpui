Code.require_file(
  "../../examples/log_trace_explorer/support/log_trace_explorer.exs",
  __DIR__
)

defmodule GPUI.LogTraceExplorerExampleTest do
  use GPUI.Test, async: false

  require Logger

  alias Examples.LogTraceExplorer.App
  alias Examples.LogTraceExplorer.Event
  alias Examples.LogTraceExplorer.Model
  alias Examples.LogTraceExplorer.Source

  test "normalizes, filters, and slices large event collections without serializing them all" do
    events =
      for sequence <- 1..100_000 do
        %{
          id: "event-#{sequence}",
          sequence: sequence,
          timestamp: "12:00:00.000",
          level: if(rem(sequence, 10) == 0, do: "error", else: "info"),
          message: "event #{sequence}",
          source: "worker",
          metadata: %{},
          search_text: "event #{sequence} worker"
        }
      end

    slice =
      Model.snapshot(events, %{
        range: Model.initial_range(),
        follow: true,
        selected_id: nil
      })

    assert slice.total == 100_000
    assert slice.offset == 99_952
    assert Enum.count_until(slice.events, 49) == 48
    assert slice.reveal_id == "event-100000"
    assert slice.reveal_index == 99_999

    broad_slice =
      Model.snapshot(events, %{
        range: %{first: 0, last: 100_000},
        follow: false,
        selected_id: nil
      })

    assert Enum.count_until(broad_slice.events, 257) == 256

    filtered = Model.filter(events, "999", "error")
    assert Enum.all?(filtered, &(&1.level == "error" and String.contains?(&1.message, "999")))
  end

  test "renders semantic levels, controlled details, filtering, and display-side copying" do
    raw_events = fixture_events()
    runtime = start_gpui!(App, args: %{events: raw_events, follow: false})

    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "log-events")
    assert runtime |> tree() |> all(type: :ui_code_line) |> length() == 4
    assert %{attrs: %{kind: "warning"}} = runtime |> tree() |> find!(id: "event-3")

    command(runtime, "focus_event_filter")
    assert %{filter_focus_request: 1} = assigns(runtime)

    select(runtime, "event_selected", "event-4")

    assert %{
             selected_id: "event-4",
             selected_index: 3,
             selected_event: %{level: "error"},
             follow: false
           } = assigns(runtime)

    assert %{type: :ui_code_viewer} = runtime |> tree() |> find!(id: "selected-event-details")
    assert text_present?(runtime, "ERROR")

    copy_selected_line(runtime, "event_message_copied")
    assert text_present?(runtime, "Copied on this display")

    change(runtime, "filter_changed", "queue")
    assigns = assigns(runtime)
    filtered = raw_events |> Model.prepare() |> Model.filter("queue", "all")
    slice = Model.snapshot(filtered, assigns)

    send_view(
      runtime,
      {:events_slice, assigns.generation, slice, length(raw_events), 0}
    )

    assert %{filter_status: :ready, total_count: 1} = assigns(runtime)
    assert %{attrs: %{id: "event-3"}} = runtime |> tree() |> find!(id: "event-3")
  end

  test "source retains bounded history while pause, follow, filtering, and clear stay controlled" do
    runtime = start_gpui!(App)
    task_supervisor = start_task_supervisor!()

    source =
      start_supervised!(
        Supervisor.child_spec(
          {Source,
           runtime: runtime, task_supervisor: task_supervisor, capacity: 3, owner: self()},
          id: make_ref()
        )
      )

    await_published(0, 0)

    for event <- fixture_events() do
      assert {:ok, _sequence} = Source.append(source, event)
    end

    await_published(3, 4)
    assert Source.retained_count(source) == 3
    assert %{retained_count: 3, dropped_count: 1, total_count: 3} = assigns(runtime)

    command(runtime, "toggle_pause")
    assert_receive {:log_trace_explorer, :controls, events}
    assert "toggle_pause" in events

    assert {:ok, 5} =
             Source.append(source, %{
               level: :error,
               source: "worker",
               message: "paused failure"
             })

    assert Source.retained_count(source) == 3
    assert runtime |> tree() |> find(id: "event-5") == nil

    command(runtime, "toggle_pause")
    assert_receive {:log_trace_explorer, :controls, events}
    assert "toggle_pause" in events
    await_published(3, 5)
    assert %{attrs: %{id: "event-5"}} = runtime |> tree() |> find!(id: "event-5")

    change(runtime, "level_changed", "error")
    assert_receive {:log_trace_explorer, :controls, events}
    assert "level_changed" in events
    await_published(2, 5)
    assert %{total_count: 2, filter_status: :ready} = assigns(runtime)

    command(runtime, "clear_events")
    assert_receive {:log_trace_explorer, :controls, events}
    assert "clear_events" in events
    await_published(0, 6)
    assert %{retained_count: 0, dropped_count: 0, total_count: 0} = assigns(runtime)
  end

  test "filter revisions include events that arrive while asynchronous work is active" do
    runtime = start_gpui!(App)
    task_supervisor = start_task_supervisor!()
    {:ok, counter} = Agent.start_link(fn -> 0 end)
    owner = self()

    filter = fn events, query, level ->
      invocation = Agent.get_and_update(counter, &{&1, &1 + 1})

      if invocation == 0 do
        send(owner, {:filter_waiting, self()})

        receive do
          :continue -> :ok
        end
      end

      Model.filter(events, query, level)
    end

    source =
      start_supervised!(
        Supervisor.child_spec(
          {Source,
           runtime: runtime, task_supervisor: task_supervisor, filter: filter, owner: self()},
          id: make_ref()
        )
      )

    assert_receive {:filter_waiting, filter_task}

    assert {:ok, 1} =
             Source.append(source, %{level: :info, source: "late", message: "late event"})

    send(filter_task, :continue)

    await_published(1, 1)
    assert %{retained_count: 1, total_count: 1} = assigns(runtime)
    assert Agent.get(counter, & &1) >= 2
  end

  test "OTP Logger handler forwards bounded events without owning source state" do
    runtime_name = GPUI.LogTraceExplorerNamedRuntime
    runtime = start_gpui!(App, name: runtime_name)
    task_supervisor = start_task_supervisor!()
    handler_id = :gpui_log_trace_explorer_test_handler
    _result = :logger.remove_handler(handler_id)
    on_exit(fn -> :logger.remove_handler(handler_id) end)

    _source =
      start_supervised!(
        Supervisor.child_spec(
          {Source,
           runtime: runtime_name,
           task_supervisor: task_supervisor,
           attach_logger: true,
           handler_id: handler_id,
           owner: self()},
          id: make_ref()
        )
      )

    await_published(0, 0)

    ExUnit.CaptureLog.capture_log(fn ->
      Logger.warning("queue depth high\nretry scheduled")
    end)

    assert_receive {:log_trace_explorer, :ingested, "event-1"}
    await_published(1, 1)

    assert %{
             retained_count: 1,
             events: [%{source: source, level: "warning", message: message}]
           } = assigns(runtime)

    assert source == "elixir"
    assert message =~ "retry scheduled"
  end

  test "event normalization bounds messages and preserves multiline detail" do
    event =
      Event.from_input(
        %{
          level: :critical,
          source: :payments,
          message: "first line\nsecond line",
          metadata: %{request_id: "req-123", payload: String.duplicate("x", 2_000)}
        },
        7
      )

    assert event.id == "event-7"
    assert event.level == "error"
    assert Event.row_text(event) =~ "first line ↵ second line"

    assert ["first line", "second line", "" | metadata_lines] = Event.detail_lines(event)
    assert "request_id: \"req-123\"" in metadata_lines

    assert metadata_lines
           |> Enum.find(&String.starts_with?(&1, "payload:"))
           |> String.length() < 600

    multiline =
      Event.from_input(%{message: Enum.map_join(1..400, "\n", &"line #{&1}")}, 8)

    assert Enum.count_until(Event.detail_lines(multiline), 257) <= 256
    assert "… additional lines omitted" in Event.detail_lines(multiline)
  end

  defp await_published(total, minimum_revision) do
    receive do
      {:log_trace_explorer, :published, _generation, ^total, _loaded, revision}
      when revision >= minimum_revision ->
        :ok

      _other ->
        await_published(total, minimum_revision)
    after
      5_000 ->
        flunk(
          "log source did not publish #{total} matching events at revision #{minimum_revision}"
        )
    end
  end

  defp start_task_supervisor! do
    start_supervised!(Supervisor.child_spec({Task.Supervisor, []}, id: make_ref()))
  end

  defp text_present?(runtime, text) do
    runtime
    |> tree()
    |> all(type: :text)
    |> Enum.any?(fn %{children: children} -> Enum.join(children) == text end)
  end

  defp fixture_events do
    [
      %{timestamp: "12:00:00.001", level: :debug, source: "cache", message: "cache hit"},
      %{timestamp: "12:00:00.002", level: :info, source: "web", message: "request complete"},
      %{
        timestamp: "12:00:00.003",
        level: :warning,
        source: "jobs",
        message: "queue depth high",
        metadata: %{queue: :exports}
      },
      %{
        timestamp: "12:00:00.004",
        level: :error,
        source: "exports",
        message: "export failed\nconnection closed"
      }
    ]
  end
end
