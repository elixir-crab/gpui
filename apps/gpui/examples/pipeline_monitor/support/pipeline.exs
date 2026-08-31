Code.require_file("fixtures.exs", __DIR__)

defmodule Examples.PipelineMonitor.Pipeline do
  use GenServer

  alias Examples.PipelineMonitor.Fixtures

  @capacity 100
  @retry_limit 3
  @history_limit 200

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  def snapshot(server \\ __MODULE__), do: GenServer.call(server, :snapshot)
  def enqueue(server \\ __MODULE__, kind), do: GenServer.call(server, {:enqueue, kind})
  def burst(server \\ __MODULE__), do: GenServer.call(server, :burst)
  def toggle_pause(server \\ __MODULE__), do: GenServer.call(server, :toggle_pause)
  def retry_failed(server \\ __MODULE__), do: GenServer.call(server, :retry_failed)
  def crash_worker(server \\ __MODULE__), do: GenServer.call(server, :crash_worker)

  @impl GenServer
  def init(opts) do
    state = %{
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      workers: Keyword.get(opts, :workers, 4),
      paused: false,
      next_id: 1,
      queue: :queue.new(),
      active: %{},
      jobs: %{},
      worker_generation: 1,
      completed_since_sample: 0
    }

    {:ok, dispatch(state)}
  end

  @impl GenServer
  def handle_call(:snapshot, _from, state), do: {:reply, public_snapshot(state), state}

  def handle_call({:enqueue, kind}, _from, state) when kind in [:success, :slow_success, :fail_once, :permanent_failure] do
    {reply, state} = enqueue_job(state, kind)
    {:reply, reply, dispatch(state)}
  end

  def handle_call(:burst, _from, state) do
    {accepted, state} =
      Fixtures.kinds()
      |> List.duplicate(2)
      |> List.flatten()
      |> Enum.reduce({0, state}, fn kind, {count, state} ->
        case enqueue_job(state, kind) do
          {{:ok, _id}, state} -> {count + 1, state}
          {{:error, :queue_full}, state} -> {count, state}
        end
      end)

    {:reply, {:ok, accepted}, dispatch(state)}
  end

  def handle_call(:toggle_pause, _from, state) do
    state = %{state | paused: not state.paused}
    {:reply, {:ok, state.paused}, dispatch(state)}
  end

  def handle_call(:retry_failed, _from, state) do
    failed = state.jobs |> Map.values() |> Enum.filter(&(&1.status == :failed))

    state =
      Enum.reduce(failed, state, fn job, state ->
        job = %{job | status: :queued, attempt: 0, worker: nil, duration_ms: nil, reason: nil}
        %{state | jobs: Map.put(state.jobs, job.id, job), queue: :queue.in(job.id, state.queue)}
      end)

    {:reply, {:ok, length(failed)}, dispatch(state)}
  end

  def handle_call(:crash_worker, _from, state) do
    case Map.values(state.active) |> List.first() do
      nil -> {:reply, {:error, :no_active_worker}, state}
      %{task: task} ->
        Process.exit(task.pid, :kill)
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_info({ref, result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case Map.pop(state.active, ref) do
      {nil, _active} -> {:noreply, state}
      {%{job_id: job_id}, active} ->
        state = %{state | active: active} |> finish_job(job_id, result) |> dispatch()
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.active, ref) do
      {nil, _active} -> {:noreply, state}
      {%{job_id: job_id}, active} ->
        job = Map.fetch!(state.jobs, job_id)
        job = %{job | status: :queued, worker: nil, reason: "worker crashed: #{inspect(reason)}"}
        state = %{state | active: active, jobs: Map.put(state.jobs, job_id, job), queue: :queue.in_r(job_id, state.queue), worker_generation: state.worker_generation + 1}
        {:noreply, dispatch(state)}
    end
  end

  defp enqueue_job(state, kind) do
    if :queue.len(state.queue) + map_size(state.active) >= @capacity do
      {{:error, :queue_full}, state}
    else
      id = "job-#{state.next_id}"
      job = %{id: id, kind: kind, status: :queued, attempt: 0, worker: nil, duration_ms: nil, reason: nil}
      {{:ok, id}, %{state | next_id: state.next_id + 1, jobs: Map.put(state.jobs, id, job), queue: :queue.in(id, state.queue)}}
    end
  end

  defp dispatch(%{paused: true} = state), do: state
  defp dispatch(state) when map_size(state.active) >= state.workers, do: state

  defp dispatch(state) do
    case :queue.out(state.queue) do
      {:empty, _queue} -> state
      {{:value, job_id}, queue} ->
        job = Map.fetch!(state.jobs, job_id)
        attempt = job.attempt + 1
        worker = "worker-#{map_size(state.active) + 1}.g#{state.worker_generation}"
        job = %{job | status: :active, attempt: attempt, worker: worker, reason: nil}
        task = Task.Supervisor.async_nolink(state.task_supervisor, fn -> execute(job.kind, attempt) end)
        state = %{state | queue: queue, jobs: Map.put(state.jobs, job_id, job), active: Map.put(state.active, task.ref, %{task: task, job_id: job_id})}
        dispatch(state)
    end
  end

  defp execute(:slow_success = kind, attempt) do
    Process.sleep(180)
    Fixtures.outcome(kind, attempt)
  end

  defp execute(kind, attempt), do: Fixtures.outcome(kind, attempt)

  defp finish_job(state, job_id, {:ok, duration}) do
    job = Map.fetch!(state.jobs, job_id)
    job = %{job | status: :completed, duration_ms: duration, reason: nil}
    %{state | jobs: Map.put(state.jobs, job_id, job), completed_since_sample: state.completed_since_sample + 1}
  end

  defp finish_job(state, job_id, {:error, reason, duration}) do
    job = Map.fetch!(state.jobs, job_id)

    if job.attempt < @retry_limit do
      job = %{job | status: :queued, duration_ms: duration, reason: reason, worker: nil}
      %{state | jobs: Map.put(state.jobs, job_id, job), queue: :queue.in(job_id, state.queue)}
    else
      job = %{job | status: :failed, duration_ms: duration, reason: reason}
      %{state | jobs: Map.put(state.jobs, job_id, job)}
    end
  end

  defp public_snapshot(state) do
    jobs = state.jobs |> Map.values() |> Enum.sort_by(&job_number/1, :desc) |> Enum.take(@history_limit)
    counts = Enum.frequencies_by(jobs, & &1.status)
    %{jobs: jobs, paused: state.paused, capacity: @capacity, workers: state.workers, worker_generation: state.worker_generation, queue_depth: :queue.len(state.queue), active_count: map_size(state.active), completed: Map.get(counts, :completed, 0), failed: Map.get(counts, :failed, 0), retry_limit: @retry_limit, throughput: state.completed_since_sample}
  end

  defp job_number(job), do: job.id |> String.trim_leading("job-") |> String.to_integer()
end

defmodule Examples.PipelineMonitor.Publisher do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    state = %{runtime: Keyword.fetch!(opts, :runtime), pipeline: Keyword.fetch!(opts, :pipeline), interval: Keyword.get(opts, :interval, 250)}
    send(self(), :publish)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:publish, state) do
    snapshot = Examples.PipelineMonitor.Pipeline.snapshot(state.pipeline)
    {:ok, _snapshot} = GPUI.Runtime.send_view(state.runtime, 1, {:pipeline_snapshot, snapshot})
    Process.send_after(self(), :publish, state.interval)
    {:noreply, state}
  end
end
