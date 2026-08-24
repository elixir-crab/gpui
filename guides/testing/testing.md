# Testing GPUI applications

`GPUI.Test` supports three complementary ExUnit layers:

1. renderer-independent application and view tests, which do not compile or
   load GPUI;
2. deterministic native interaction tests backed by GPUI's `TestAppContext`;
3. real desktop E2E for operating-system and compositor behavior.

Configure desktop consumers with `config :gpui, build_native: config_env() !=
test` so ordinary test builds retain the fast renderer-independent boundary.

## Local native E2E

Run the same desktop E2E suite through the platform-aware local orchestrator:

```sh
mix gpui.test.e2e test/e2e/gpui/native/motion_test.exs
mix gpui.test.e2e test/e2e/gpui/native
```

On Linux the task checks `xvfb-run`, D-Bus, and `xdotool`, then runs with
Xvfb and Lavapipe. On macOS it checks Accessibility and Screen Recording
permission, builds the Swift desktop driver, and uses the active WindowServer
and real Metal renderer. Both paths execute ordinary ExUnit tests through
`GPUITest.Desktop`; no separate test runner is involved.

The source-built native artifacts for ordinary, deterministic-native, and
real-desktop modes are isolated. Verify the complete transition sequence without
cleaning build directories or deleting a NIF artifact:

```sh
mix gpui.test.mode_switch
mix gpui.test.mode_switch test/e2e/gpui/native/form_controls_test.exs
```

This runs ordinary ExUnit, deterministic native ExUnit, one focused desktop E2E,
ordinary ExUnit again, and deterministic native ExUnit again. It is intentionally
serial because the desktop step owns process-global pointer and focus state.

## Deterministic native interaction tests

Use the same test case with a `:native` option when behavior depends on GPUI
layout, focus, hit testing, or keyboard dispatch:

```elixir
defmodule MyApp.SettingsNativeTest do
  use GPUI.Test, native: [size: {320, 160}]

  test "radio navigation skips disabled choices", %{ui: ui} do
    render(ui, SettingsView, plan: "free", notifications: false)

    focus(ui, "plan")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui,
                    {:event,
                     %{type: :change, event: "plan_changed", value: "team"}}}

    # Controlled state remains in Elixir: render the acknowledged value.
    render(ui, SettingsView, plan: "team", notifications: false)
  end
end
```

`use GPUI.Test, native: ...` marks the module `:native`, requires synchronous
ExUnit execution, starts a supervised UI for each test, and supplies its opaque
handle as `%{ui: ui}`. The imported interaction vocabulary is deliberately
small:

```elixir
render(ui, SettingsView, plan: "free")
focus(ui, "plan")
press(ui, :space)
click(ui, "notifications")
click(ui, {24, 48})
scroll(ui, "records", delta: {0, -240})
type(ui, "Ada")
resize(ui, {800, 600})
advance(ui, 250)
assert %{width: width, height: height} = bounds(ui, "notifications")
settle(ui)
```

Stable IDs come from declarative `id` attributes. `click/2` targets the center
of the corresponding rendered bounds or an explicit `{x, y}` logical point;
`bounds/2` returns `%{x:, y:, width:, height:}` in logical pixels. `scroll/3`
dispatches a bounded logical-pixel wheel delta at a stable target's center.
`type/2` dispatches platform text input to the focused control, while `resize/2` changes
the deterministic viewport. `advance/2` moves GPUI's test clock by a bounded
number of milliseconds and then settles pending work. `press/2` accepts semantic keys such as
`:arrow_left`, `:arrow_right`, `:arrow_up`, `:arrow_down`, `:space`, `:enter`,
`:escape`, and `:tab`, or a GPUI keystroke string.

Native events use ordinary ExUnit mailbox assertions rather than a custom
assertion language:

```elixir
click(ui, "notifications")

assert_receive {:gpui, ^ui,
                {:event,
                 %{type: :change, event: "notifications_changed", value: true}}}
```

The Elixir test owns fixtures, assigns, actions, controlled rerenders, and
assertions. The native side is a generic interpreter around GPUI's
`TestAppContext`; component-specific fixtures and assertions do not belong in
Rust.

Run the isolated Mix-target build with:

```sh
mix gpui.test.native
mix gpui.test.native test/gpui/test/native/controls_test.exs
mix gpui.test.native test/gpui/my_settings_native_test.exs
```

The task selects `MIX_TARGET=native_test`, leaving ordinary `MIX_ENV=test`
renderer-independent. RustQ generates the NIF exports and Elixir stubs for the
closed native-test command boundary.

Deterministic collection tests live under
`test/gpui/test/native/collections_test.exs`. They cover native keyboard
selection, disabled-item skipping, source-backed range requests after scrolling,
and full-snapshot variable collections across empty, populated, remeasured,
tail-following, and empty states. Desktop collection E2E should therefore focus
on actual OS wheel delivery, compositor behavior, and real-window stability.

The deterministic harness installs the same `gpui_component::Root` layer used by
production windows, so dialog opening and Escape closure can exercise the real
top-layer path. Real-window focus containment, content activation, and trigger
restoration remain desktop-owned facts.

`gpui-component::InputState` calls the public macOS content-type helper while
rendering a focused input. That helper correctly treats an unavailable raw
window handle as “no native content-type integration”, but GPUI's `TestWindow`
currently panics instead of returning `raw_window_handle::HandleError` from its
handle traits. A two-line upstream GPUI correction to return
`HandleError::NotSupported` makes controlled input render and edit through the
real component path. GPUI does not carry a dependency-checkout patch, so input
remains blocked until the pinned GPUI revision includes that truthful behavior.
Desktop E2E continues to own IME, native content types, selection, and clipboard.

These tests verify deterministic renderer behavior, not operating-system facts.
Real desktop E2E remains necessary for native window creation,
application-owned chrome, OS close requests, clipboard integration, external
file drops, IME behavior, accessibility adapters, and compositor output.

## Deterministic application tests

```elixir
defmodule MyApp.FocusTimerTest do
  use GPUI.Test, async: true

  test "starts and receives OTP ticks" do
    runtime = start_runtime!(GettingStarted.FocusTimer.App, args: %{seconds: 2})

    click(runtime, "start")
    send_view(runtime, :tick)

    assert %{remaining: 1, status: :running} = assigns(runtime)
  end
end
```

`start_runtime!/2` starts a supervised `GPUI.Runtime` backed by
`GPUI.Test.Display`. Events pass through the same runtime polling and session
dispatch boundaries used by a real display.

## Rendering and querying

Render a view directly when runtime behavior is not needed:

```elixir
tree = render(MyApp.ProfileView, name: "Ada", editing: false)
assert %GPUI.Element{type: :ui_input} = find!(tree, id: "name")
assert [_button] = all(tree, type: :ui_button)
```

Runtime helpers expose snapshots, selected windows, assigns, and rendered trees:

```elixir
snapshot = snapshot(runtime)
window = window_snapshot(snapshot, "Settings")
assigns = assigns(runtime)
tree = tree(runtime)
```

`render/2` returns the original `%GPUI.Element{}` tree, while `tree/2` returns
the snapshot-encoded map sent across display boundaries. `find/2`, `find!/2`,
and `all/2` intentionally query either representation; pattern matches should
use the corresponding struct or map shape.

## Semantic events

Use the helper matching the component contract:

```elixir
click(runtime, "save")
command(runtime, "reload_repository")
change(runtime, "name_changed", "Ada")
submit(runtime, "save", "Ada")
select(runtime, "language_changed", "elixir")
search(runtime, "framework_searched", "live")
change(runtime, "notifications_changed", true)
change(runtime, "details_changed", ["account"])
change(runtime, "volume_changed", 75.0)
release(runtime, "volume_released", 75.0)
change(runtime, "dialog_open_changed", true)
dispatch(runtime, %{type: :select, window_id: 1, event: "file_menu_selected", value: "new"})
file_select(runtime, "source_selected", "fixture.png", encoded_png)
file_cancel(runtime, "source_selected")
range(runtime, "records_range", 1_000, 1_048)
```

All helpers return the resulting snapshot. `dispatch/2` is available for custom
explicit typed events. Every routed event must include a positive `window_id`,
a non-empty `event` name, and the value shape required by its `type`; missing
`type` never defaults to `:click`. The convenience helpers construct those
fields for tests. `send_view/3` delivers an OTP message through
`GPUI.Runtime.send_view/3`, making background-process behavior deterministic
without running timers in a test.

## Coverage ownership

Choose the lowest layer that can prove the behavior:

| Test layer | Primary responsibility | Examples |
| --- | --- | --- |
| Renderer-independent `use GPUI.Test` | Elixir application state, callbacks, validation, snapshots, topology, protocol policy | `handle_event/3`, controlled assigns, window reconciliation, schema errors |
| Deterministic `use GPUI.Test, native: ...` | GPUI layout, bounds, hit testing, native focus, keyboard dispatch, component mechanics | disabled-option skipping, tree navigation, pointer activation, controlled native rerenders |
| Desktop E2E | Facts owned by the OS, window server, accessibility adapter, or compositor | native chrome, OS close, clipboard, external drops, IME, target-window capture |
| Visual capture | Pixel-level appearance rather than behavior | spacing, clipping, contrast, popup placement, theme variants |

Do not duplicate deterministic component assertions in desktop E2E. Once
native interaction coverage exists, retain only the platform-specific smoke
assertions in the E2E test. Conversely, a renderer-independent event injection
test does not prove GPUI focus, hit testing, or keyboard behavior.

## Test layout

The repository separates tests by purpose:

- `test/gpui/` contains focused unit, deterministic view-state, schema/template,
  and deterministic native interaction tests;
- `test/integration/gpui/examples/` contains example source processes,
  Logger/ETS/filesystem work, cancellation, and other cross-process flows;
- `test/integration/` contains remaining runtime, transport, and remote-flow
  tests;
- `test/e2e/` contains real native-window tests;
- `test/support/` contains reusable displays and native drivers.

Run focused renderer-independent layers with:

```bash
mix test test/gpui test/gpui_test.exs
mix test test/integration
```

Run deterministic GPUI interaction tests separately:

```bash
mix gpui.test.native
```

Run native-window tests as standard ExUnit in the desktop build environment:

```bash
MIX_ENV=e2e mix test --only e2e test/e2e
```

## Native E2E

The native suite is ordinary ExUnit. `MIX_ENV=e2e` selects the desktop native
Cargo features at compile time. On Linux, run ExUnit inside an isolated Xvfb
and D-Bus session; Mesa Lavapipe provides software rendering and `xdotool`
provides XTest pointer and keyboard input:

```bash
MIX_ENV=e2e RUST_FONTCONFIG_DLOPEN=1 LIBGL_ALWAYS_SOFTWARE=1 \
  GALLIUM_DRIVER=llvmpipe xvfb-run -a dbus-run-session -- \
  mix test --only e2e test/e2e
```

Display-server orchestration stays outside Mix and ExUnit. On a workstation
with an existing display, use the plain `MIX_ENV=e2e mix test ...` command.

The suite verifies real hit testing, focus, input editing, selection, clipboard,
controlled rerenders, component popups, overlay dismissal, remote display
behavior, window closure, snapshot shrink, and runtime isolation. It does not
require a desktop environment or window manager.

Install the Linux E2E dependencies with:

```bash
sudo apt-get install xvfb xdotool libxkbcommon-dev libxkbcommon-x11-dev
```

Behavioral E2E assertions are not a substitute for visual review. Deterministic
capture definitions currently live under `test/visual/scenarios/`; they are
capture-tool support rather than ExUnit test runners. The consolidated
component gallery is the canonical component capture surface, while product
showcases retain scenario-specific states. Capture one scenario or the complete
suite with:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture \
  --scenario component_gallery \
  --theme dark \
  --output tmp/gpui-visual-dark

RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture \
  --scenario beam_observatory \
  --theme dark \
  --output tmp/beam-observatory-visual

RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture --all --output tmp/gpui-visual
```

Each module implements the repository's visual scenario behaviour and declares
its application, initial arguments, window title, capture names, and actions such as event
dispatch, root-view messages, and synchronized hover. The generic runner owns
Xvfb startup, completed-frame barriers, pointer movement, file naming, and
cleanup. Scenarios must not sample live state when stable screenshots are
required.

Inspect the resulting images for spacing, clipping, contrast, popup placement,
and state variants. `GPUITest.Desktop.capture!/2` remains a single-purpose
explicit capture helper for repository E2E tests; it does not wait, inspect
environment variables, or choose paths.

## Full quality gate

```bash
mix ci
MIX_ENV=e2e RUST_FONTCONFIG_DLOPEN=1 LIBGL_ALWAYS_SOFTWARE=1 \
  GALLIUM_DRIVER=llvmpipe xvfb-run -a dbus-run-session -- \
  mix test --only e2e test/e2e
```

`mix ci` also checks generated Rust freshness, Cargo formatting and feature
matrices, Clippy with warnings denied, Rust unit tests, Credo, Dialyzer,
duplication, and architecture policy.
