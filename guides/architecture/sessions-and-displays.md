# Sessions, runtimes, and displays

GPUI separates renderer-independent application state from display lifecycle.
This keeps view logic deterministic, permits local and remote presentation, and
prevents native window ownership from leaking into application processes.

## Session

`GPUI.Session` owns:

- window specifications and root-view assigns;
- rendered `%GPUI.Snapshot{}` values;
- resource metadata;
- event dispatch and bounded event history.

A session does not own a native event loop or platform window. Its boundary is
serializable Elixir data.

## Display

A `GPUI.Display` receives snapshots and returns normalized events. The package
ships two principal implementations:

- `GPUI.Display.Native` presents snapshots through Rust GPUI windows;
- `GPUI.Test.Display` records snapshots and accepts deterministic injected events.

Remote clients can also mount a native display against a session hosted by
`GPUI.Remote.Server`.

Custom displays implement `GPUI.Display`. Startup must return `{:ok, pid}` or
`{:error, reason}`; synchronization must return `:ok` or `{:error, reason}`;
event draining must return `{:ok, events}` or `{:error, reason}`; and injection
must return an `:ok` or `:error` tuple. GPUI rejects invalid returns as
`{:invalid_display_return, callback, value}` and catches callback failures as
`{:display_callback_failed, callback, kind, reason}`.

## Runtime

`GPUI.Runtime` composes one session with one display. It synchronizes snapshots,
polls display events, dispatches event batches through the session, and sends
the resulting snapshot back to the display.

```elixir
{:ok, runtime} =
  GPUI.Runtime.start_link(
    app: MyApp.Desktop,
    args: %{account_id: account_id},
    display: GPUI.Display.Native,
    poll_interval: 16
  )
```

Normally the application module is placed directly in a supervision tree and
its generated child specification starts the runtime.

Supervised workers can update a root view without pretending that application
work is native input:

```elixir
{:ok, snapshot} = GPUI.Runtime.send_view(runtime, window_id, {:loaded, records})
```

The selected view receives the message in `handle_info/2`. The runtime then
synchronizes and publishes the resulting snapshot.

Runtime updates are available through ordinary OTP messages:

```elixir
:ok = GPUI.Runtime.subscribe(runtime)

receive do
  {:gpui, ^runtime, %GPUI.Runtime.Update{revision: revision, events: events, snapshot: snapshot}} ->
    # The snapshot has already been synchronized to the active display.
end

:ok = GPUI.Runtime.unsubscribe(runtime)
```

Revisions increase monotonically within a runtime. Subscribers are monitored
and removed automatically when they exit. Frame synchronization is separate
from snapshot synchronization: `GPUI.Runtime.await_frame/3` waits until the
current snapshot generation has completed a frame, without blocking the runtime
from processing messages.

Native-only changes such as hover, focus, tooltip timers, and IME state can be
synchronized with a completed-frame token:

```elixir
{:ok, generation} = GPUI.Runtime.frame_token(runtime, window_id)
# Send native platform input here.
:ok = GPUI.Runtime.await_frame_after(runtime, window_id, generation)
```

`GPUI.Runtime.request_frame/1` resynchronizes the current snapshot when callers
need an explicit frame without changing application state. Runtime operations
return structured `:display_start_failed`, `:display_sync_failed`,
`:display_drain_failed`, and `:display_inject_failed` errors instead of crashing
when a custom display fails its contract. Session mutations happen before display
synchronization; after a synchronization error, `request_frame/1` retries the
current authoritative snapshot.

## Native process model

Native displays share one process-global GPUI application loop. That loop owns
all platform windows, while commands and registry state remain scoped to their
originating runtime and window IDs.

Loop acquisition is platform-specific behind the same host boundary:

- on macOS, the host asks ERTS to hand the original process main thread to GPUI,
  satisfying AppKit's main-thread requirement without moving application state
  out of Elixir;
- on Linux and Windows, the host starts one permanent dedicated native GUI
  thread and keeps every window on that thread.

Startup is acknowledged only after the GPUI application has initialized. The
last runtime releasing its windows does not tear down and recreate the
process-global application loop.

Commands are acknowledged: callers receive success, timeout, disconnection, or
stopped-runtime outcomes instead of enqueue-only success. Native frame barriers
track snapshot and completed-frame generations per window and acknowledge after
the corresponding frame has passed prepaint and presentation submission. Closing the
final window does not terminate the shared loop. Runtime shutdown is
non-blocking and cleans up only that runtime's windows and component state.

## Declarative viewport

Each rendered window tree is wrapped by a renderer-internal `:viewport` node in
Elixir before it crosses a display boundary. The node establishes the current
window content bounds; it is included in native and remote snapshots but is not
a public template tag. Rust interprets those declared viewport semantics and
does not inject application-specific layout wrappers.

Application roots should declare how they consume the viewport. A flex root
normally uses `grow` and `w-full`; definite `w-full` and `h-full` lengths remain
available where the parent layout provides a definite corresponding dimension.
This keeps viewport declaration, layout values, defaults, and component policy
in Elixir while leaving platform window state in GPUI.

## Snapshot reconciliation

A snapshot contains the complete declarative window set. Native synchronization:

1. creates missing windows;
2. updates existing window trees and resources;
3. removes windows absent from the next snapshot;
4. reconciles stateful controls by component kind and stable ID;
5. drops registry entries no longer present in the rendered tree.

Window snapshots also carry bounded command ID/shortcut pairs. The native root
observes matched keystrokes after normal GPUI dispatch, emits `:command` events,
and suppresses standard editing combinations while an input is focused.

Component IDs never depend on traversal position. Duplicate structural IDs are
rejected before crossing the display boundary.

## RustQ boundary

RustQ generates repetitive native boundaries from GPUI's internal schema:

- source-discovered atoms and Rustler NIF exports;
- resource contracts and decoders;
- window, primitive-element, component, and event-value decoders authored as typed Rusty-Elixir where their behavior is renderer-independent;
- source-derived renderer routing and element dispatch;
- style dispatch;
- disabled-feature NIF implementations;
- stateful registry kinds and typed accessors.

Component defaults and attribute constraints come from the same schema used by
public builders and native decoding. Renderer metadata is indexed from the real
Rust functions in one pass instead of maintained in a parallel route table.

GPUI lifecycle, entities, focus, callbacks, reconciliation behavior, and
platform integration remain handwritten Rust. Shared native collection
mechanics live in a handwritten uniform-collection core; listbox and tree
keyboard and accessibility semantics remain in their focused renderers. This
keeps generated code structural while preserving readable native behavior.

See [Remote displays](remote-displays.html) for transport topology and
[Testing GPUI applications](testing.html) for renderer-independent testing.
