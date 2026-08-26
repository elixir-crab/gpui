# Resources and display actions

File pickers, clipboards, and external paths belong to the machine running the
`GPUI.Display`. This matters for remote applications: a user's display machine
may not share a filesystem or clipboard with the BEAM host.

GPUI transfers bounded facts rather than product policy. The framework does not
infer MIME types, open dropped paths, upload attachments, traverse directories,
or decide whether application code should trust a selected resource.

## Display-machine ownership

Treat every external path as meaningful only on the display machine. Application
code remains responsible for:

- file type and size validation;
- reading files and handling permissions;
- upload and attachment lifecycle;
- MIME and application-format interpretation;
- project-relative path conversion;
- command execution and security policy.

When an application needs portable bytes rather than a display-local path, use
the bounded file-picker action described below. It reads on the display machine
and emits bytes through the normal event path.

## Read a selected file

`phx-file-read` on `button/1` opens the platform picker on the display machine,
reads one selected file, and emits bytes rather than a path:

```elixir
<UI.button
  id="source-image"
  label="Choose image"
  file_prompt="Choose an image"
  file_max_bytes={25 * 1_024 * 1_024}
  phx-file-read="image-selected"
/>
```

`file_max_bytes` defaults to 10 MiB and is bounded to `1..25 MiB`. The event
value is one of:

```elixir
%{
  operation_id: 42,
  status: :selected,
  name: "photo.png",
  size: 12_345,
  data: encoded_bytes
}

%{operation_id: 42, status: :cancelled}
%{operation_id: 42, status: :error, reason: "permission denied"}
```

The stable operation ID distinguishes separate picker requests. `name` is the
selected display-side basename, not an application-authoritative identity.
Validate the bytes and format before using them.

If the button also declares clipboard and ordinary click events, clipboard
operations run first, then the file read, then `phx-click`.

## Read and write clipboard text

An explicit clipboard-read action retrieves bounded text from the display
machine:

```elixir
<UI.button
  id="paste"
  label="Paste"
  phx-clipboard-read="clipboard-read"
/>
```

The handler receives a canonical public payload:

```elixir
def handle_event(
      "clipboard-read",
      %{value: %GPUI.Transfer.Payload{text: text, external_paths: []}},
      assigns
    ) do
  {:noreply, %{assigns | pasted_text: text}}
end
```

Clipboard text is valid UTF-8 and bounded to 1 MiB. A non-text, empty, or
oversized clipboard produces `text: nil`; arbitrary MIME bytes are not exposed.
When `phx-click` is also present, the clipboard event is emitted first.

Write bounded text by pairing `clipboard_text` with
`phx-clipboard-write`:

```elixir
<UI.button
  id="copy-css"
  label="Copy CSS"
  clipboard_text={assigns.css}
  phx-clipboard-write="css-copied"
/>
```

The named event acknowledges that the platform write was requested. It does not
turn clipboard contents into application-owned state or promise that another
process has consumed them.

Native editable text keeps its immediate platform copy, paste, selection, and
IME behavior. Use explicit clipboard payload events only when application policy
needs to inspect text before accepting it.

## External path drops

`GPUI.UI.drop_target/1` receives external-path drag sessions without reading the
files:

```elixir
<UI.drop_target
  id="attachments"
  phx-drag-enter="attachments-entered"
  phx-drag-move="attachments-moved"
  phx-drag-leave="attachments-left"
  phx-drop="attachments-dropped"
  class="p-6 border rounded-lg"
>
  <text>Drop files here</text>
</UI.drop_target>
```

Handlers receive a normalized `GPUI.Transfer.Event`:

```elixir
def handle_event(
      "attachments-dropped",
      %{value: %GPUI.Transfer.Event{} = transfer},
      assigns
    ) do
  paths = transfer.payload.external_paths
  {:noreply, %{assigns | pending_display_paths: paths}}
end
```

A transfer event contains:

```elixir
%GPUI.Transfer.Event{
  session_id: 42,
  target_id: "attachments",
  position: {320.0, 180.0},
  coordinate_space: :window_native_pixels,
  payload: %GPUI.Transfer.Payload{
    text: nil,
    external_paths: ["/display/tmp/document.pdf"]
  }
}
```

`:drag_enter` and `:drop` include the bounded payload. `:drag_move` carries the
latest position without repeating paths and may be display-side coalesced.
`:drag_leave` terminates the session. The renderer-owned monotonic session ID
prevents stale movement or leave events from being associated with a later
drag.

Payload bounds are:

| Value | Bound |
| --- | ---: |
| Text | 1 MiB |
| Unique external paths | 64 |
| One UTF-8 path | 4 KiB |
| All unique paths | 256 KiB |
| Stable target ID | 128 bytes |

Duplicate paths are removed in first-seen order. Invalid or unrepresentable
UTF-8 paths are rejected rather than converted lossily.

## Remote behavior

File reads, clipboard operations, and drops occur where the display runs. Remote
paths are never rewritten as BEAM-host paths. Bounded bytes and canonical event
values travel through the ordinary remote protocol.

Remote clipboard and external-path support use additive capabilities. A peer
that did not advertise the relevant capability cannot send the corresponding
event. Capabilities are renegotiated after reconnection before queued transfer
events resume.

Applications should not branch their window or element topology based on where
the display runs. Provide an ordinary controlled fallback when a display cannot
perform an optional platform action.

## Images and raster resources

`GPUI.Image.decode/1` converts common encoded image bytes into a validated
`GPUI.Raster`. Decoding runs on a dirty CPU scheduler; keep file access and
larger workflows in supervised tasks:

```elixir
with {:ok, raster} <- GPUI.Image.decode(encoded_bytes) do
  GPUI.Runtime.put_resource(runtime, "preview", GPUI.Raster.to_payload(raster))
end
```

Render a one-off inline raster with:

```elixir
<img raster={raster} label="Preview" />
```

`label` provides the native accessibility name. For images retained across
multiple view updates, install the raster once and render a reference:

```elixir
<img raster={GPUI.ResourceRef.new("preview", :raster)} label="Preview" />
```

Resource references avoid copying the complete pixel payload through each later
snapshot and work across local and remote displays.

## Deterministic testing

Renderer-independent helpers exercise application policy without opening native
pickers or touching the host clipboard:

```elixir
file_select(runtime, "image-selected", "fixture.png", encoded_png)
file_cancel(runtime, "image-selected")
```

Construct typed transfer values directly when testing drop policy:

```elixir
payload = GPUI.Transfer.Payload.new(external_paths: ["/display/tmp/report.csv"])

transfer = %GPUI.Transfer.Event{
  session_id: 17,
  target_id: "attachments",
  position: {20.0, 30.0},
  coordinate_space: :window_native_pixels,
  payload: payload
}
```

Use renderer-independent tests for bounds, normalization, routing, and
application decisions. Use desktop E2E for real clipboard, picker, and external
drop behavior. Deterministic native tests may cover target layout and routing,
but they do not establish operating-system transfer facts.

See [Transfer payload internals](transfers.html) for the pinned native capability
analysis, renderer session mechanics, remote capability enforcement, and
intentionally deferred formats.
