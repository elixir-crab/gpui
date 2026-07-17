# BEAM process explorer

A live desktop view of processes on the current BEAM node.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/process_explorer/run.exs
```

The application demonstrates a larger GPUI architecture:

- an OTP worker samples `Process.list/0` and `Process.info/2`;
- `GPUI.Runtime.send_view/3` delivers snapshots to the root view;
- filtering, sorting, selection, and pause state remain controlled in Elixir;
- a native scroll container presents the process collection;
- selecting a row opens a process inspector without a second source of truth;
- tests use synthetic process snapshots through `GPUI.Test` and do not need a
  native window.

Capture deterministic overview and selected-process screenshots with:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture \
  --example process_explorer \
  --theme dark \
  --output tmp/process-explorer-visual
```

The renderer caps the visible result set at 500 rows. Filtering happens before
the cap, so large nodes remain inspectable without constructing an unbounded
native element tree. This is deliberately a normal collection rather than a
claim of virtualized-list support; a future virtualized collection primitive
should replace the cap.
