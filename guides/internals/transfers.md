# Transfer payload internals

This guide records the native and transport boundary behind the public
application contract in
[Resources and display actions](resources-and-display-actions.html). GPUI
transfers bounded clipboard and operating-system file facts without moving
attachment, upload, filesystem, or product policy into the renderer.

## Native capability boundary

The pinned GPUI revision exposes:

- `ClipboardItem` with string, image, and `ExternalPaths` entries;
- platform clipboard read and write operations;
- `FileDropEvent::{Entered, Pending, Submit, Exited}`;
- `ExternalPaths` as display-machine `PathBuf` values;
- drag-over, drag-move, and drop listeners for typed native values.

GPUI translates an operating-system file drop into an internal drag containing
`ExternalPaths`. `Entered` is the only platform phase carrying the paths; later
pending and submit phases carry position while GPUI retains the active drag
value. The renderer therefore owns a bounded drag session that preserves the
payload until terminal drop or leave.

The public clipboard layer does not expose arbitrary MIME byte entries
coherently across supported platforms. GPUI must not advertise a generic
clipboard-format API by treating platform-specific or internal representations
as a portable contract.

## Renderer-owned drag sessions

The renderer assigns each native drag a monotonic session ID and retains:

- the canonical bounded `GPUI.Transfer.Payload`;
- the currently hit stable target ID;
- the latest window-relative native-pixel position;
- whether enter, movement, leave, or drop is pending.

Enter and drop include the retained payload. Movement is high frequency and can
be coalesced to the latest position without losing ordered terminal facts. Leave
and drop close the session so stale native callbacks cannot attach to a later
drag.

Routing uses ordinary element hit testing and typed runtime events. It does not
introduce a generic effect bus, synchronous pointer NIF, or renderer-owned
application object.

## Canonical protocol representation

`GPUI.Transfer.Payload` and `GPUI.Transfer.Event` are the public normalized
values. Their wire maps use bounded UTF-8 strings, finite numeric coordinates,
a closed `window_native_pixels` coordinate space, and explicit payload presence
by event phase.

Validation occurs before session dispatch for local and remote events. Paths
that cannot be represented as bounded UTF-8 are rejected rather than converted
lossily. Duplicate paths are removed in first-seen order. No protocol decoder
opens a path, reads a file, infers MIME, or constructs an attachment.

Generated event decoding and handwritten native session mechanics share this
canonical Elixir-owned schema; native structs are not a public protocol.

## Clipboard ordering

Button activation can request clipboard read, clipboard write, a bounded file
read, and an ordinary click. The renderer executes them in this order:

```text
clipboard operations
→ file read
→ ordinary click
```

This makes the event sequence deterministic while preserving each operation as
an explicit opt-in. Clipboard reads emit `GPUI.Transfer.Payload`; writes emit an
acknowledgement after requesting the platform operation.

Native editable text does not route ordinary paste through this explicit button
contract. Its immediate platform selection, paste, and IME behavior update the
native buffer, and the resulting revisioned transaction is the
application-visible fact.

## Remote capability enforcement

Remote transfer support is additive within the exact current protocol version:

```text
clipboard_text_v1
external_path_transfer_v1
```

A display forwards an event only when the corresponding capability was
negotiated. The server retains peer capabilities per connection and rejects
transfer events from a peer that did not advertise support. Reconnection runs a
fresh hello before queued events resume.

Remote paths remain facts about the display machine and are never rewritten as
BEAM-host paths. Bounds are checked before transport and again before runtime
dispatch. Movement may be display-side coalesced; enter, leave, and drop remain
ordered session facts.

## Resource and allocation ownership

The bounded file-picker action reads one file on the display machine because its
purpose is to produce portable bytes. Larger workflows remain supervised
application tasks rather than long-lived renderer operations.

Decoded raster data can be installed as a runtime resource and referenced from
later snapshots. Native code owns allocation and image decoding mechanics;
Elixir owns resource identity, lifetime policy, replacement, and application
meaning.

## Deferred capabilities

The current transfer contract intentionally excludes:

- arbitrary MIME or custom clipboard bytes;
- automatic reads of externally dropped paths;
- automatic uploads or directory traversal;
- drag sources and cross-application data promises;
- clipboard history or global observation;
- application-specific attachment objects;
- clipboard images until they have a bounded renderer-independent resource
  contract across platforms;
- streaming transfer payloads without explicit flow control and cancellation.

Additions must remain bounded, serializable, display-machine-aware, and neutral
about product policy.
