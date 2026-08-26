# Application tests

Renderer-independent tests prove Elixir application behavior without compiling
or loading GPUI. They are the default for state transitions, callbacks,
validation, snapshots, topology, event policy, and supervised integration.

Use asynchronous ExUnit where the application under test permits it:

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

## Render and query views

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

## Dispatch semantic events

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
file_select(runtime, "source_selected", "fixture.png", encoded_png)
file_cancel(runtime, "source_selected")
range(runtime, "records_range", 1_000, 1_048)
```

All helpers return the resulting snapshot. `dispatch/2` remains available for a
custom explicit typed event:

```elixir
dispatch(runtime, %{
  type: :select,
  window_id: 1,
  event: "file_menu_selected",
  value: "new"
})
```

Every routed event requires a positive `window_id`, a non-empty `event` name,
and the value shape required by its `type`; a missing `type` never defaults to
`:click`. Convenience helpers construct those fields for tests.

`send_view/3` delivers an OTP message through `GPUI.Runtime.send_view/3`, making
background-process behavior deterministic without running timers in a test.

## What this layer proves

Application tests should own:

- `mount/1`, `handle_event/3`, `handle_info/2`, and window callback behavior;
- controlled assigns and authoritative rerenders;
- schema, template, and payload validation;
- snapshot topology and dynamic windows;
- source-backed range and selection policy;
- remote protocol, reconnection, and synchronization policy;
- text-buffer transactions that do not require a mounted native surface.

They do not prove where GPUI laid out an element, whether native focus moved,
whether a key reached a component, or whether the operating system completed a
clipboard or IME operation. Use [Deterministic native tests](native-tests.html)
or [Desktop E2E and visual evidence](desktop-e2e.html) for those facts.

## Repository test layout

The repository separates tests by purpose:

- `test/gpui/` contains focused units, deterministic view-state tests,
  schema/template tests, and deterministic native interaction tests;
- `test/integration/gpui/examples/` contains example source processes,
  Logger/ETS/filesystem work, cancellation, and other cross-process flows;
- `test/integration/` contains remaining runtime, transport, and remote flows;
- `apps/gpui_native/test/e2e/` contains real native-window tests;
- `test/support/` contains reusable displays and native drivers.

Run focused renderer-independent layers with:

```bash
mix test test/gpui test/gpui_test.exs
mix test test/integration
```

Tests under `test/gpui/test/native/` are selected by the dedicated native-test
Mix target and are not part of the ordinary renderer-independent command.
