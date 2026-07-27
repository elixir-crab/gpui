# Commands and keyboard shortcuts

GPUI windows can bind application-owned command IDs to modified keyboard
shortcuts. A command uses the same event ID as a button or menu action, so the
root view keeps one handler regardless of how the user invokes it.

## Declare window shortcuts

Declare shortcuts next to the window rather than inside transient rendered
controls:

```elixir
window "Repository" do
  size(1200, 760)
  shortcut("reload_repository", "primary-r")
  shortcut("focus_repository_filter", "primary-f")
  root(MyApp.RepositoryView, filter: "", filter_focus_request: 0)
end
```

`primary` means Command on macOS and Control on other platforms. `ctrl`, `alt`,
and `shift` may also be combined, for example `primary-shift-k`. Shortcuts must
contain `primary`, `ctrl`, or `alt` plus one lowercase key. Each window supports
at most 64 commands, and command IDs and shortcuts must be unique.

Command definitions are renderer-independent window metadata. They cross local
and remote display boundaries with the rest of the snapshot while native GPUI
performs platform keystroke matching.

## Share command IDs with controls

A button can emit the same ID:

```elixir
<UI.button
  id="refresh"
  label="Refresh"
  phx-click="reload_repository"
/>
```

Both the button click and `primary-r` reach the same handler:

```elixir
@impl GPUI.View
def handle_event("reload_repository", _event, assigns) do
  {:noreply, %{assigns | scan_status: :scanning}}
end
```

Keyboard commands use event type `:command`; buttons use `:click`. The event ID
and view handler are shared. Native command observation runs after normal GPUI
key handling and does not intercept propagation. Editing shortcuts handled by a
focused input therefore retain their native behavior instead of also invoking a
window command.

## Focus commands

Combine a command with a monotonic input focus request:

```elixir
@impl GPUI.View
def handle_event("focus_repository_filter", _event, assigns) do
  {:noreply, %{assigns | filter_focus_request: assigns.filter_focus_request + 1}}
end
```

```elixir
<UI.input
  id="repository-filter"
  label="Repository filter"
  value={assigns.filter}
  focus_request={assigns.filter_focus_request}
  phx-change="filter_changed"
/>
```

The repository workspace, process table, and log stream examples use this
pattern for refresh, pause, clear, and filter-focus commands.

## Deterministic tests

`GPUI.Test.command/3` invokes the same application handler without Rust or a
display server:

```elixir
command(runtime, "reload_repository")
assert %{scan_status: :scanning} = assigns(runtime)
```

Use native E2E tests only for platform shortcut matching and focus-sensitive
interaction.
