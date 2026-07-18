# BEAM process explorer

A live desktop view of processes on the current BEAM node.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/process_explorer/run.exs
```

The application demonstrates a larger GPUI architecture:

- an OTP worker samples `Process.list/0` and `Process.info/2`;
- `GPUI.Runtime.send_view/3` delivers snapshots to the root view;
- filtering, sorting, selection, pause state, and empty-state feedback remain
  controlled in Elixir;
- `GPUI.UI.virtual_list/1` renders only the visible process rows and preserves scroll state;
- pointer or keyboard selection opens a process inspector without a second source of truth;
- filtered summaries distinguish visible rows from the full sample, while a
  selected process can remain inspectable when the current filter hides it;
- tests use synthetic process snapshots through `GPUI.Test` and do not need a
  native window.

Rows have stable PID-based IDs and a uniform declared height. Filtering and
sorting happen in Elixir, while GPUI's native uniform list constructs and lays
out only the visible range. Controlled selection is revealed with the nearest
scroll strategy.
