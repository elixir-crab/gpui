GPUITest.Examples.load!(:beam_control_room)

defmodule GPUITest.Visual.BeamControlRoom.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :beam_control_room

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.BeamControlRoom.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{snapshot: snapshot()}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "BEAM Control Room"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "runtime-health"},
      %{name: "selected-process", actions: [change("process_selected", "<0.50.0>")]},
      %{name: "filtered-processes", actions: [change("filter_changed", "worker")]}
    ]
  end

  defp change(event, value),
    do: {:dispatch, %{type: :change, window_id: 1, event: event, value: value}}

  defp snapshot do
    %{
      processes: [
        process("<0.50.0>", "code_server", 4_300_000, 0, 1_110_155, ":code_server.loop/1"),
        process("<0.81.0>", "worker", 1_900_000, 18, 384_202, "Worker.consume/1"),
        process("<0.72.0>", "telemetry", 620_000, 2, 82_100, "Telemetry.dispatch/4"),
        process("<0.45.0>", "logger", 280_000, 0, 42_001, ":gen_server.loop/7")
      ],
      tables: [
        table(":code", 42_100, 5_100),
        table(":sessions", 12_840, 1_204),
        table(":cache", 8_210, 620),
        table(":metrics", 4_400, 301)
      ],
      memory: %{
        total: 82_000_000,
        processes: 31_000_000,
        binary: 12_000_000,
        ets: 8_000_000,
        code: 20_000_000,
        atom: 1_400_000
      },
      run_queue: 2,
      schedulers: 8,
      ports: 24,
      sampled_at: "12:34:56"
    }
  end

  defp process(pid, name, memory, mailbox, reductions, function) do
    %{
      pid: pid,
      name: name,
      status: "waiting",
      message_queue_len: mailbox,
      memory: memory,
      reductions: reductions,
      current_function: function,
      initial_call: function
    }
  end

  defp table(name, memory, size) do
    %{
      id: name,
      tid: nil,
      name: name,
      owner: "<0.50.0>",
      type: "set",
      protection: "protected",
      size: size,
      memory: memory,
      named: true
    }
  end
end
