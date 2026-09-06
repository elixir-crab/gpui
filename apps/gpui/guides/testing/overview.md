# Testing GPUI applications

`GPUI.Test` supports three complementary ExUnit layers. Choose the lowest layer
that can truthfully prove the behavior:

| Test layer | Use it for | Do not claim |
| --- | --- | --- |
| Renderer-independent `use GPUI.Test` | Elixir state, callbacks, validation, snapshots, topology, and protocol policy | GPUI layout, native focus, or OS behavior |
| Deterministic `use GPUI.Test, native: ...` | GPUI layout, bounds, hit testing, focus, keyboard dispatch, and component mechanics | OS clipboard, IME, compositor, or real-window behavior |
| Repository desktop E2E | Window-server, accessibility-adapter, clipboard, IME, external transfer, and compositor facts | A replacement for focused component tests |

Pixel-level appearance belongs to synchronized visual capture rather than a
behavioral assertion.

## Choose a guide

- [Application tests](application-tests.html) covers fast renderer-independent
  view and runtime tests, tree queries, semantic event helpers, and repository
  test layout.
- [Deterministic native tests](native-tests.html) covers real GPUI component
  mechanics through `TestAppContext` without a desktop window.
- [Desktop E2E and visual evidence](desktop-e2e.html) covers platform-aware
  orchestration, real native windows, and synchronized captures.
- [Test coverage ownership](coverage-ownership.html) is the authoritative
  behavior-by-layer matrix.

Configure consumers with:

```elixir
config :gpui_native, build_native: config_env() != :test
```

This keeps ordinary application tests free of GPUI compilation and native
library loading. The repository isolates the ordinary, deterministic-native,
and desktop native artifacts, so switching modes does not require deleting a
shared NIF.

## Avoid duplicated coverage

Do not duplicate deterministic component assertions in desktop E2E. Once native
interaction coverage proves a component mechanic, retain only the
platform-specific smoke assertion in E2E. Conversely, renderer-independent
event injection does not prove focus, hit testing, keyboard dispatch, or native
layout.

## Full quality gate

Run the normal project gate with:

```bash
mix ci
```

It checks generated Rust freshness, Cargo formatting and feature matrices,
Clippy with warnings denied, Rust unit tests, ExUnit, Credo, Dialyzer,
duplication, and architecture policy.

Real-window coverage is deliberately separate because it requires platform
orchestration:

```bash
mix gpui.test.e2e apps/gpui_native/test/e2e/gpui/native
```

When changing native modes or validating artifact isolation, run:

```bash
mix gpui.test.mode_switch
```

See [Desktop E2E and visual evidence](desktop-e2e.html) for focused
commands and platform requirements.
