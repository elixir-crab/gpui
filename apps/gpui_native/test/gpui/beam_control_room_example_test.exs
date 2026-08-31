GPUITest.Examples.load!(:beam_control_room)

defmodule GPUI.BeamControlRoomExampleTest do
  use GPUI.Test, async: true

  test "presents runtime health and drills into hot processes" do
    sample = sample()
    runtime = start_runtime!(Examples.BeamControlRoom.App, args: %{snapshot: sample})

    assert %{title: "BEAM Control Room", size: [1320, 820]} = window_snapshot(runtime)
    assert %{run_queue: 2, schedulers: 8, paused: false} = assigns(runtime)
    assert %{type: :ui_data_table} = runtime |> tree() |> find!(id: "control-room-processes")

    change(runtime, "process_selected", "<0.50.0>")
    assert %{selected_pid: "<0.50.0>"} = assigns(runtime)

    change(runtime, "filter_changed", "worker")
    assert %{query: "worker"} = assigns(runtime)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(&match?(%{children: ["worker"]}, &1))
  end

  test "pauses sampling and reconciles terminated selections" do
    runtime = start_runtime!(Examples.BeamControlRoom.App, args: %{snapshot: sample()})

    change(runtime, "process_selected", "<0.50.0>")
    click(runtime, "toggle-pause")
    send_view(runtime, {:control_room_snapshot, %{sample() | processes: []}})
    assert %{paused: true, selected_pid: "<0.50.0>"} = assigns(runtime)

    click(runtime, "toggle-pause")
    send_view(runtime, {:control_room_snapshot, %{sample() | processes: []}})
    assert %{paused: false, selected_pid: nil, processes: []} = assigns(runtime)
  end

  defp sample do
    %{
      processes: [
        %{
          pid: "<0.50.0>",
          name: "worker",
          status: "waiting",
          message_queue_len: 3,
          memory: 1_048_576,
          reductions: 123_456,
          current_function: "Worker.loop/1",
          initial_call: "Worker.init/1"
        },
        %{
          pid: "<0.51.0>",
          name: "scheduler",
          status: "running",
          message_queue_len: 0,
          memory: 262_144,
          reductions: 98_765,
          current_function: "Scheduler.run/0",
          initial_call: "Scheduler.init/1"
        }
      ],
      tables: [
        %{
          id: "users",
          tid: :users,
          name: ":users",
          owner: "<0.50.0>",
          type: "set",
          protection: "protected",
          size: 420,
          memory: 8_400,
          named: true
        },
        %{
          id: "cache",
          tid: :cache,
          name: ":cache",
          owner: "<0.51.0>",
          type: "set",
          protection: "public",
          size: 120,
          memory: 2_400,
          named: true
        }
      ],
      memory: %{
        total: 16_777_216,
        processes: 5_242_880,
        binary: 2_097_152,
        ets: 1_048_576,
        code: 4_194_304,
        atom: 524_288
      },
      run_queue: 2,
      schedulers: 8,
      ports: 12,
      sampled_at: "12:34:56"
    }
  end
end
