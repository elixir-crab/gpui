GPUITest.Examples.load!(:pipeline_monitor)

defmodule GPUI.PipelineMonitorExampleTest do
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
         task_supervisor: task_supervisor, name: unique_name(:pipeline), workers: 1}
      )

    {:ok, _id} = Examples.PipelineMonitor.Pipeline.enqueue(pipeline, :fail_once)
    Process.sleep(30)

    assert %{completed: 1, failed: 0, jobs: [%{attempt: 2, status: :completed}]} =
             Examples.PipelineMonitor.Pipeline.snapshot(pipeline)

    {:ok, true} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    {:ok, _id} = Examples.PipelineMonitor.Pipeline.enqueue(pipeline, :success)
    assert %{paused: true, queue_depth: 1} = Examples.PipelineMonitor.Pipeline.snapshot(pipeline)
    {:ok, false} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    Process.sleep(20)

    {:ok, true} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    {:ok, _id} = Examples.PipelineMonitor.Pipeline.enqueue(pipeline, :slow_success)
    generation = Examples.PipelineMonitor.Pipeline.snapshot(pipeline).worker_generation
    {:ok, false} = Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
    Process.sleep(5)
    :ok = Examples.PipelineMonitor.Pipeline.crash_worker(pipeline)
    Process.sleep(20)
    assert Examples.PipelineMonitor.Pipeline.snapshot(pipeline).worker_generation > generation
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
