# BEAM Control Room

BEAM Control Room is the OTP-specific flagship example. A supervised sampler
reads process, scheduler, memory, port, and ETS state; the Elixir view owns
filtering, selection, pause policy, and every rendered snapshot.

The interface follows a native operations-console structure rather than a card
dashboard:

- compact runtime status strip;
- searchable process table as the primary surface;
- selected process inspector;
- ranked ETS ownership and memory information;
- supervised periodic sampling with pause/resume.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run apps/gpui/examples/beam_control_room/run.exs
```

For state-preserving view reload:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev apps/gpui/examples/beam_control_room/run.exs
```
