# Pipeline Monitor

Pipeline Monitor demonstrates an OTP-owned bounded queue, concurrent supervised
Tasks, deterministic retry policy, failure history, pause/resume, worker crash
recovery, and periodic publication into a controlled GPUI view.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/pipeline_monitor/run.exs
```

The process topology is:

```text
GPUI.Runtime
Examples.PipelineMonitor.Pipeline
Task.Supervisor
Examples.PipelineMonitor.CommandRouter
Examples.PipelineMonitor.Publisher
```

Fixture kinds are deterministic: success, slow success, fail once, and permanent
failure. The interface is a primary jobs table with one selected-job and worker
pool inspector, not a metrics dashboard.
