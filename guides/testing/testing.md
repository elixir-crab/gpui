# Testing GPUI applications

`GPUI.Test` provides deterministic ExUnit helpers without loading the native NIF
or requiring a display server. Native interaction tests remain a separate E2E
layer.

## Deterministic application tests

```elixir
defmodule MyApp.CounterTest do
  use GPUI.Test, async: true

  test "increments" do
    runtime = start_gpui!(MyApp.Desktop)

    assert %{count: 0} = assigns(runtime)
    click(runtime, "increment")
    assert %{count: 1} = assigns(runtime)
  end
end
```

`start_gpui!/2` starts a supervised `GPUI.Runtime` backed by
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

## Semantic events

Use the helper matching the component contract:

```elixir
click(runtime, "save")
change(runtime, "name_changed", "Ada")
select(runtime, "language_changed", "elixir")
search(runtime, "framework_searched", "live")
toggle(runtime, "notifications_changed", true)
expand(runtime, "details_changed", ["account"])
slide(runtime, "volume_changed", 75.0)
release(runtime, "volume_released", 75.0)
open(runtime, "dialog_open_changed", true)
menu_select(runtime, "file_menu_selected", "new")
```

All helpers return the resulting snapshot. `dispatch/2` is available for custom
normalized events.

## Test layout

The repository separates tests by purpose:

- `test/gpui/` contains focused unit and schema/template tests;
- `test/integration/` contains runtime, transport, and remote-flow tests;
- `test/e2e/` contains real native-window tests;
- `test/support/` contains reusable displays and native drivers.

Run focused layers with:

```bash
mix test_unit
mix test_integration
mix test_e2e
```

## Native E2E

`mix test_e2e` compiles the desktop native feature set and launches ExUnit under
an isolated Xvfb server. Mesa Lavapipe provides software rendering and `xdotool`
provides XTest pointer and keyboard input.

The suite verifies real hit testing, focus, input editing, selection, clipboard,
controlled rerenders, component popups, overlay dismissal, remote display
behavior, window closure, snapshot shrink, and runtime isolation. It does not
require a desktop environment or window manager.

Install the Linux E2E dependencies with:

```bash
sudo apt-get install xvfb xdotool libxkbcommon-dev libxkbcommon-x11-dev
```

Behavioral E2E assertions are not a substitute for visual review. Before a
release that changes rendering, capture the synchronized component gallery:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture --output tmp/gpui-visual
```

The task runs under Xvfb, requests an explicit platform frame, waits on the
native generation barrier, and captures components, popovers, dialogs, and
menus. Inspect the resulting images for spacing, clipping, contrast, popup
placement, and state variants. `GPUITest.E2E.Desktop.capture!/2` remains a
single-purpose explicit capture helper for repository E2E tests; it does not
wait, inspect environment variables, or choose paths.

## Full quality gate

```bash
mix ci
mix test_e2e
RUST_FONTCONFIG_DLOPEN=1 mix gpui.release.check
```

`mix ci` also checks generated Rust freshness, Cargo formatting and feature
matrices, Clippy with warnings denied, Rust unit tests, Credo, Dialyzer,
duplication, and architecture policy.
