Code.require_file("pipeline.exs", __DIR__)

defmodule Examples.PipelineMonitor.View do
  use GPUI.View
  alias GPUI.UI

  @impl GPUI.View
  def render(assigns) do
    selected = Enum.find(assigns.jobs, &(&1.id == assigns.selected_id))

    ~GPUI"""
    <div class="flex w-full h-full min-h-0 flex-col bg-white">
      <div class="flex items-center justify-between px-4 py-3 border-b border-slate-200 bg-slate-50">
        <div class="flex flex-col"><text class="text-lg font-semibold text-slate-900">Pipeline Monitor</text><text class="text-sm text-slate-500">Bounded queue · deterministic retries · supervised workers</text></div>
        <div class="flex gap-2"><UI.button id="add-job" label="Add job" phx-click="add_job" /><UI.button id="add-burst" label="Add burst" phx-click="add_burst" /><UI.button id="toggle-pause" label={if(assigns.paused, do: "Resume", else: "Pause")} variant={if(assigns.paused, do: "primary", else: "default")} phx-click="toggle_pause" /></div>
      </div>
      <div class="flex items-center gap-5 px-4 py-2 border-b border-slate-200">{stat("Queue", "#{assigns.queue_depth}/#{assigns.capacity}")}{stat("Active", assigns.active_count)}{stat("Completed", assigns.completed)}{stat("Failed", assigns.failed)}{stat("Throughput", "#{assigns.throughput} jobs/s")}<div class="flex grow" /><text class={if(assigns.paused, do: "text-sm text-amber-700", else: "text-sm text-green-700")}>{if(assigns.paused, do: "PAUSED", else: "RUNNING")}</text></div>
      <div class="flex grow min-h-0">
        <div class="flex grow min-w-0 min-h-0 flex-col border-r border-slate-200"><div class="flex items-center justify-between px-4 py-3"><text class="font-semibold text-slate-900">Jobs</text><div class="flex gap-2"><UI.button id="retry-failed" label="Retry failed" disabled={assigns.failed == 0} phx-click="retry_failed" /><UI.button id="crash-worker" label="Crash worker" disabled={assigns.active_count == 0} variant="danger" phx-click="crash_worker" /></div></div>{job_table(assigns.jobs, assigns.selected_id)}</div>
        <scroll class="flex w-[340px] min-h-0 bg-slate-50 p-4"><div class="flex flex-col w-full gap-5">{job_inspector(selected)}{worker_pool(assigns)}{policy(assigns)}</div></scroll>
      </div>
      <UI.status_bar id="pipeline-status"><UI.status_item id="pipeline-status-left" side="left"><text class="text-sm text-slate-500">Generation {assigns.worker_generation}</text><UI.separator id="pipeline-separator" orientation="vertical" /><text class="text-sm text-slate-500">{assigns.workers} workers</text></UI.status_item><UI.status_item id="pipeline-status-right" side="right"><text class="text-sm text-slate-500">Retry limit {assigns.retry_limit}</text></UI.status_item></UI.status_bar>
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("job_selected", %{value: id}, assigns), do: {:noreply, %{assigns | selected_id: id}}
  def handle_event("add_job", _event, assigns), do: {:noreply, %{assigns | command: {:enqueue, next_kind(assigns)}}}
  def handle_event("add_burst", _event, assigns), do: {:noreply, %{assigns | command: :burst}}
  def handle_event("toggle_pause", _event, assigns), do: {:noreply, %{assigns | command: :toggle_pause}}
  def handle_event("retry_failed", _event, assigns), do: {:noreply, %{assigns | command: :retry_failed}}
  def handle_event("crash_worker", _event, assigns), do: {:noreply, %{assigns | command: :crash_worker}}

  @impl GPUI.View
  def handle_info({:pipeline_snapshot, snapshot}, assigns) do
    selected_id = if Enum.any?(snapshot.jobs, &(&1.id == assigns.selected_id)), do: assigns.selected_id
    {:noreply, assigns |> Map.merge(snapshot) |> Map.put(:selected_id, selected_id) |> Map.put(:command, nil)}
  end

  defp job_table(jobs, selected) do
    columns = [UI.table_column(%{id: "id", label: "Job", width: 100}), UI.table_column(%{id: "kind", label: "Kind", width: 180}), UI.table_column(%{id: "status", label: "Status", width: 120}), UI.table_column(%{id: "attempt", label: "Attempt", width: 80, align: "right"}), UI.table_column(%{id: "worker", label: "Worker", width: 160}), UI.table_column(%{id: "duration", label: "Duration", width: 100, align: "right"})]
    rows = Enum.map(jobs, fn job -> UI.table_row(%{id: job.id, children: [job.id, humanize(job.kind), humanize(job.status), Integer.to_string(job.attempt), job.worker || "—", duration(job.duration_ms)]}) end)
    UI.data_table(%{id: "pipeline-jobs", label: "Pipeline jobs", selected: selected, reveal: selected, item_height: 36, header_height: 30, "phx-change": "job_selected", class: "grow", children: columns ++ rows})
  end

  defp job_inspector(nil), do: section("Selected job", "Select a job to inspect attempts, worker assignment, duration, and failure reason.")
  defp job_inspector(job) do
    assigns = %{job: job}
    ~GPUI"""
    <div class="flex flex-col gap-3"><text class="font-semibold text-slate-900">{assigns.job.id}</text>{detail("Kind", humanize(assigns.job.kind))}{detail("Status", humanize(assigns.job.status))}{detail("Attempt", assigns.job.attempt)}{detail("Worker", assigns.job.worker || "—")}{detail("Duration", duration(assigns.job.duration_ms))}{detail("Reason", assigns.job.reason || "—")}</div>
    """
  end

  defp worker_pool(assigns) do
    content = "#{assigns.active_count} active of #{assigns.workers} · generation #{assigns.worker_generation}"
    section("Worker pool", content)
  end

  defp policy(assigns), do: section("Queue policy", "Capacity #{assigns.capacity} · retry limit #{assigns.retry_limit} · FIFO dispatch")
  defp section(title, content) do
    assigns = %{title: title, content: content}
    ~GPUI"""
    <div class="flex flex-col gap-2 border-t border-slate-200 pt-4"><text class="font-semibold text-slate-900">{assigns.title}</text><text class="text-sm text-slate-600">{assigns.content}</text></div>
    """
  end
  defp stat(label, value) do
    assigns = %{label: label, value: value}
    ~GPUI"""
    <div class="flex items-baseline gap-2"><text class="text-sm text-slate-500">{assigns.label}</text><text class="font-semibold text-slate-900">{assigns.value}</text></div>
    """
  end
  defp detail(label, value) do
    assigns = %{label: label, value: value}
    ~GPUI"""
    <div class="flex flex-col gap-1"><text class="text-sm text-slate-500">{assigns.label}</text><text class="text-sm text-slate-900">{assigns.value}</text></div>
    """
  end
  defp next_kind(assigns), do: Enum.at(Examples.PipelineMonitor.Fixtures.kinds(), rem(length(assigns.jobs), 4))
  defp humanize(value), do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()
  defp duration(nil), do: "—"
  defp duration(value), do: "#{value} ms"
end

defmodule Examples.PipelineMonitor.App do
  use GPUI.Application

  @impl GPUI.Application
  def identity do
    GPUI.Application.Identity.new!(id: "dev.gpui.pipeline-monitor", name: "Pipeline Monitor", icon: GPUI.Application.Icon.new!(source: "priv/branding/pipeline-monitor", description: "Pipeline Monitor application icon"))
  end

  @impl GPUI.Application
  def mount(args) do
    snapshot = args |> Map.new() |> Map.get(:snapshot, %{jobs: [], paused: false, capacity: 100, workers: 4, worker_generation: 1, queue_depth: 0, active_count: 0, completed: 0, failed: 0, retry_limit: 3, throughput: 0})
    {:ok, [window "Pipeline Monitor" do size(1240, 760); root(Examples.PipelineMonitor.View, Map.merge(snapshot, %{selected_id: nil, command: nil})) end]}
  end
end

defmodule Examples.PipelineMonitor.CommandRouter do
  use GenServer
  alias GPUI.Runtime

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  @impl GenServer
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime); :ok = Runtime.subscribe(runtime)
    {:ok, %{runtime: runtime, pipeline: Keyword.fetch!(opts, :pipeline)}}
  end
  @impl GenServer
  def handle_info({:gpui, runtime, %GPUI.Runtime.Update{snapshot: snapshot}}, %{runtime: runtime} = state) do
    command = snapshot.windows |> hd() |> get_in([:root, :assigns, :command])
    execute(command, state.pipeline)
    {:noreply, state}
  end
  defp execute(nil, _pipeline), do: :ok
  defp execute({:enqueue, kind}, pipeline), do: Examples.PipelineMonitor.Pipeline.enqueue(pipeline, kind)
  defp execute(:burst, pipeline), do: Examples.PipelineMonitor.Pipeline.burst(pipeline)
  defp execute(:toggle_pause, pipeline), do: Examples.PipelineMonitor.Pipeline.toggle_pause(pipeline)
  defp execute(:retry_failed, pipeline), do: Examples.PipelineMonitor.Pipeline.retry_failed(pipeline)
  defp execute(:crash_worker, pipeline), do: Examples.PipelineMonitor.Pipeline.crash_worker(pipeline)
end
