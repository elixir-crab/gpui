# Learning examples

Run these in order from the repository root:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/02_events.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/03_supervised_updates.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/04_controlled_form.exs
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/getting_started/05_multiple_windows.exs
```

Each lesson introduces one idea:

1. **Window** — `GPUI.Application`, `GPUI.View`, and one declarative window.
2. **Events** — controlled state updated by native click events.
3. **Supervised updates** — a supervised `GenServer` sends messages to the view.
4. **Controlled form** — validation and form values remain in Elixir.
5. **Multiple windows** — event outcomes change declarative window topology.

The implementation modules live under `support/` so the examples can also run
through `GPUI.Test` without opening native windows.
