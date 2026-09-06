GPUITest.Examples.load!(:pipeline_monitor)

defmodule GPUITest.Visual.PipelineMonitor.Scenario do
  @behaviour GPUI.Maintainer.Visual.Scenario

  @impl true
  def id, do: :pipeline_monitor
  @impl true
  def app, do: Examples.PipelineMonitor.App
  @impl true
  def title, do: "Pipeline Monitor"
  @impl true
  def args(_theme), do: %{snapshot: snapshot()}

  @impl true
  def captures do
    [
      %{name: "running"},
      %{name: "selected-retry", actions: [change("job_selected", "job-3")]},
      %{name: "paused", actions: [click("toggle_pause")]},
      %{name: "failed", actions: [change("job_selected", "job-4")]}
    ]
  end

  defp snapshot do
    %{
      jobs: [
        job("job-4", :permanent_failure, :failed, 3, "worker-2.g1", 36, "invalid payload"),
        job("job-3", :fail_once, :completed, 2, "worker-3.g1", 48, nil),
        job("job-2", :slow_success, :active, 1, "worker-2.g1", nil, nil),
        job("job-1", :success, :completed, 1, "worker-1.g1", 24, nil)
      ],
      paused: false,
      capacity: 100,
      workers: 4,
      worker_generation: 1,
      queue_depth: 6,
      active_count: 1,
      completed: 2,
      failed: 1,
      retry_limit: 3,
      throughput: 12
    }
  end

  defp job(id, kind, status, attempt, worker, duration, reason),
    do: %{
      id: id,
      kind: kind,
      status: status,
      attempt: attempt,
      worker: worker,
      duration_ms: duration,
      reason: reason
    }

  defp click(event), do: {:dispatch, %{type: :click, window_id: 1, event: event}}

  defp change(event, value),
    do: {:dispatch, %{type: :change, window_id: 1, event: event, value: value}}
end
