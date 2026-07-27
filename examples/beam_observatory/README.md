# BEAM Observatory

BEAM Observatory consolidates the former process and ETS inspectors into one
runtime-health application. The main view emphasizes operational signals rather
than presenting two unrelated tables:

- process, memory, scheduler, ETS, and port metrics;
- a declarative memory map;
- runtime-pressure signals;
- searchable hot-process drill-down;
- process details and ranked ETS tables;
- supervised periodic sampling with pause/resume.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/beam_observatory/run.exs
```

For state-preserving view reload:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev examples/beam_observatory/run.exs
```
