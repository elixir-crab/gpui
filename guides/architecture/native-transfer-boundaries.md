# Native transfer payload boundaries

GPUI applications need clipboard and operating-system file-drop facts without
moving attachment, upload, filesystem, or product policy into the renderer.
This guide records the first neutral boundary before the protocol is exposed.

## Display-machine ownership

Clipboard contents and external paths always belong to the machine running the
`GPUI.Display`. A remote display therefore reports paths on the remote display
machine, not paths on the BEAM host. The framework never reads a dropped path,
uploads it, resolves project-relative meaning, or assumes that another display
can open it.

Consumers retain responsibility for:

- file type and size validation;
- reading files and handling permission failures;
- upload and attachment lifecycle;
- MIME and application-format interpretation;
- project-relative path conversion;
- command execution and security policy.

## Pinned native capabilities

The pinned GPUI revision exposes:

- `ClipboardItem` with string, image, and `ExternalPaths` entries;
- platform clipboard read and write operations;
- `FileDropEvent::{Entered, Pending, Submit, Exited}`;
- `ExternalPaths` as display-machine `PathBuf` values;
- ordinary drag-over, drag-move, and drop listeners for typed native values.

GPUI translates an operating-system file drop into an internal drag containing
`ExternalPaths`. `Entered` is the only phase carrying the paths; later pending
and submit phases carry position while GPUI retains the active drag value.
This makes a renderer-owned bounded drag session necessary before emitting
Elixir events.

The pinned public clipboard contract does not provide arbitrary MIME byte
entries. The framework must not advertise a generic clipboard-format API until
the native platforms expose one coherently. The first contract should therefore
cover text and external paths only; clipboard images can be considered later
through existing bounded raster/resource machinery.

## First payload contract

The initial renderer-independent payload should be equivalent to:

```elixir
%GPUI.Transfer.Payload{
  text: nil | String.t(),
  external_paths: [String.t()]
}
```

Proposed hard limits:

```text
text                         1 MiB
external paths               64
one encoded path             4 KiB
all encoded paths            256 KiB
```

Paths that are not representable as bounded UTF-8 strings must be rejected
explicitly rather than lossily converted. Duplicate paths should be removed in
first-seen order. Payloads contain facts only; no path is opened or read.

## Event contract

A drop target opts into fixed typed phases:

```text
:drag_enter
:drag_move
:drag_leave
:drop
```

Each event includes a window-native-pixel position. `:drag_enter` and `:drop`
include the bounded payload. `:drag_move` is coalesced and carries only the
session identity and latest position. `:drag_leave` terminates the session.
A monotonically increasing renderer-owned session ID prevents stale movement
or leave events from being associated with a later drag.

A target must use a stable element ID. Enter/move/drop routing uses normal
hit-testing and ordinary typed runtime events; no generic effect bus or
synchronous pointer NIF is introduced.

## Clipboard contract

Clipboard integration begins with explicit opt-in operations rather than a
global clipboard subscription. An ordinary `GPUI.UI.button/1` opts into a
clipboard read with `phx-clipboard-read`. Its user activation reads bounded
display-machine clipboard text and emits `:clipboard` with `%GPUI.Transfer.Payload{}` through `phx-clipboard-read`.
```heex
<UI.button
  id="paste"
  label="Paste"
  phx-clipboard-read="clipboard_read"
/>
```

When both `phx-click` and `phx-clipboard-read` are present, the bounded
clipboard event is emitted first and the ordinary click follows. Non-text, empty, or text over 1 MiB produces `text: nil`; arbitrary MIME bytes
are never exposed. Ordinary `GPUI.UI.button/1` activation may write bounded
`clipboard_text` through `phx-clipboard-write`.

Remote clipboard events require the additive `:clipboard_text_v1` capability.

Native editable text keeps its immediate platform paste and IME behavior. The
buffer transaction remains the authoritative application-visible result.
Clipboard payload events are needed only when a consumer requests external
path facts or wants to apply policy before accepting a transfer.

## Remote displays

Transfer support uses the additive `:external_path_transfer_v1` capability
within the exact remote protocol version. A display forwards transfer events
only when that capability appears in the server hello response. The server
retains peer capabilities per connection, rejects transfer events from peers
that did not advertise the capability, and validates bounded transfer values
before session dispatch. Reconnection performs a fresh hello before queued
transfer events resume.

A remote display that lacks transfer support must reject or
omit the opt-in feature explicitly. Remote paths are never rewritten as BEAM
host paths, and payload bytes remain bounded before transport.

High-frequency movement is display-side coalesced. Enter, leave, and drop are
ordered terminal facts and are never silently coalesced away.

## Deferred capabilities

The first transfer contract intentionally excludes:

- arbitrary MIME/custom clipboard bytes;
- automatic file reads or uploads;
- directory traversal;
- drag sources and cross-application data promises;
- clipboard history or observation;
- application-specific attachment objects;
- images until a bounded renderer-independent resource contract is selected.
