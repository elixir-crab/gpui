GPUI.TestSupport.Examples.load!(:pipeline_monitor)

defmodule GPUI.Examples.PipelineMonitorTest do
  use GPUI.Test, async: true

  test "renders controlled pipeline snapshots and selection" do
    snapshot = fixture_snapshot()
    runtime = start_runtime!(Examples.PipelineMonitor.App, args: %{snapshot: snapshot})

    assert %{title: "Pipeline Monitor", size: [1240, 760]} = window_snapshot(runtime)
    assert %{completed: 1, failed: 1, paused: false} = assigns(runtime)
    assert %{type: :ui_data_table} = runtime |> tree() |> find!(id: "pipeline-jobs")

    change(runtime, "job_selected", "job-2")
    assert %{selected_id: "job-2"} = assigns(runtime)
  end

  test "pipeline bounds queue, retries, pauses, and replaces crashed workers" do
    task_supervisor = start_supervised!({Task.Supervisor, name: unique_name(:tasks)})

    pipeline =
      start_supervised!(
        {Examples.PipelineMonitor.Pipeline,
         task_supervisor: task_supervisor,
         name: unique_name(:pipeline),
         workers: 1,
         notify: self()}
      )

    {:ok, _id} = Examples.PipelineMonitor.Pipeline.enqueue(pipeline, :fail_once)

    assert_receive {:pipeline, ^pipeline,
                    %{completed: 1, failed: 0, jobs: [%{attempt: 2, status: :completed}]}},
                   1_000

    {:ok, true} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    {:ok, _id} = Examples.PipelineMonitor.Pipeline.enqueue(pipeline, :success)
    assert %{paused: true, queue_depth: 1} = Examples.PipelineMonitor.Pipeline.snapshot(pipeline)
    {:ok, false} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    assert_receive {:pipeline, ^pipeline, %{completed: 2}}, 1_000

    {:ok, true} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    {:ok, _id} = Examples.PipelineMonitor.Pipeline.enqueue(pipeline, :slow_success)
    generation = Examples.PipelineMonitor.Pipeline.snapshot(pipeline).worker_generation
    {:ok, false} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    :ok = Examples.PipelineMonitor.Pipeline.crash_worker(pipeline)

    assert_receive {:pipeline, ^pipeline, %{worker_generation: current}}
                   when current > generation,
                   1_000
  end

  defp fixture_snapshot do
    %{
      jobs: [
        %{
          id: "job-2",
          kind: :permanent_failure,
          status: :failed,
          attempt: 3,
          worker: "worker-2.g1",
          duration_ms: 36,
          reason: "invalid payload"
        },
        %{
          id: "job-1",
          kind: :success,
          status: :completed,
          attempt: 1,
          worker: "worker-1.g1",
          duration_ms: 24,
          reason: nil
        }
      ],
      paused: false,
      capacity: 100,
      workers: 4,
      worker_generation: 1,
      queue_depth: 0,
      active_count: 0,
      completed: 1,
      failed: 1,
      retry_limit: 3,
      throughput: 1
    }
  end

  defp unique_name(prefix), do: String.to_atom("#{prefix}_#{System.unique_integer([:positive])}")
end
