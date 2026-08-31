Code.require_file("support/pipeline_monitor.exs", __DIR__)

runtime_name = Examples.PipelineMonitor.Runtime
pipeline_name = Examples.PipelineMonitor.Pipeline
worker_supervisor = Examples.PipelineMonitor.TaskSupervisor

{:ok, runtime} = GPUI.Runtime.start_link(name: runtime_name, app: Examples.PipelineMonitor.App)
{:ok, _tasks} = Task.Supervisor.start_link(name: worker_supervisor)
{:ok, pipeline} = Examples.PipelineMonitor.Pipeline.start_link(name: pipeline_name, task_supervisor: worker_supervisor)
{:ok, _router} = Examples.PipelineMonitor.CommandRouter.start_link(runtime: runtime, pipeline: pipeline)
{:ok, _publisher} = Examples.PipelineMonitor.Publisher.start_link(runtime: runtime, pipeline: pipeline)

for kind <- [:success, :fail_once, :slow_success, :permanent_failure], do: Examples.PipelineMonitor.Pipeline.enqueue(pipeline, kind)

IO.puts("Pipeline Monitor is running. Press Ctrl+C twice to exit.")
GPUI.Dev.wait(runtime, files: Path.wildcard(Path.join(__DIR__, "support/*.exs")))
