# OTP Log and Trace Explorer

A supervised desktop explorer for live OTP Logger events.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/log_trace_explorer/run.exs
```

The example installs a lightweight Logger handler and includes a supervised
producer so useful debug, info, warning, error, metadata, and multiline states
appear immediately. Logs from the running application are captured as well;
other supervised trace producers can call
`Examples.LogTraceExplorer.Source.append/2` with the same bounded event maps.

## Architecture

- `Examples.LogTraceExplorer.LoggerHandler` performs only a mailbox send from
  Logger's synchronous handler callback.
- `Examples.LogTraceExplorer.Source` owns the complete bounded event model and
  keeps accepting events while the view is paused or a filter task is running.
- Filtering runs under `Task.Supervisor`; task revisions prevent stale results
  from replacing a newer source generation.
- The GPUI snapshot contains only the loaded source-backed slice (capped at 256
  rows) plus one selected event's bounded multiline details.
- Capacity defaults to 10,000 retained events and is capped at 100,000. Oldest
  events are dropped deterministically while sequence IDs remain stable.
- `GPUI.UI.code_viewer/1` provides native virtualization, controlled selection,
  distant tail reveal, horizontal scrolling, keyboard navigation, and semantic
  debug/info/warning/error presentation.
- Message copying executes on the display machine, preserving useful semantics
  for remote sessions.

Pause stops snapshot updates but not ingestion. Follow-tail can be disabled to
inspect historical ranges. Filters search message text, source, level, and
bounded metadata. Selecting an event exposes its multiline message and metadata
in a second code viewer.

Tests use direct source appends and Logger events with mailbox acknowledgements;
they do not rely on finite sleeps or a native display.
