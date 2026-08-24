# Resources and display actions

File pickers and clipboards belong to the machine running the display. Raster
resources provide a bounded, serializable path for decoded image data across
local and remote sessions.

## Display-side actions

`phx-file-read` on `button/1` opens the platform picker on the machine running
the display. It reads one selected file with a bounded size and emits bytes
rather than a filesystem path, so the same event remains meaningful for remote
displays. `file_max_bytes` defaults to 10 MiB and cannot exceed 25 MiB.

```elixir
<UI.button
  id="source-image"
  label="Choose image"
  file_prompt="Choose an image"
  file_max_bytes={25 * 1_024 * 1_024}
  phx-file-read="image_selected"
/>
```

The event value is one of:

```elixir
%{operation_id: 42, status: :selected, name: "photo.png", size: 12_345, data: encoded_bytes}
%{operation_id: 42, status: :cancelled}
%{operation_id: 42, status: :error, reason: "..."}
```

An ordinary `button/1` writes bounded `clipboard_text` to the clipboard owned by
the local display when `phx-clipboard-write` is present. The named event is
emitted after the platform write is requested. This gives remote applications
the expected user-side clipboard rather than the application server's
clipboard.

```elixir
<UI.button
  id="copy-css"
  label="Copy CSS"
  clipboard_text={assigns.css}
  phx-clipboard-write="css_copied"
/>
```

Tests select or cancel files deterministically with `GPUI.Test.file_select/5`
and `GPUI.Test.file_cancel/3`; neither helper opens a native window.

## Images and raster resources

`GPUI.Image.decode/1` converts common encoded image bytes into a validated
`GPUI.Raster`. Decoding runs on a dirty CPU scheduler; applications should keep
file access and larger workflows in supervised tasks.

```elixir
with {:ok, bytes} <- File.read(path),
     {:ok, raster} <- GPUI.Image.decode(bytes) do
  GPUI.Runtime.put_resource(runtime, "preview", GPUI.Raster.to_payload(raster))
end
```

Render an inline raster with `<img raster={raster} label="Preview" />`; `label`
provides its native accessibility name. For images that survive
multiple view updates, install the raster once and render
`GPUI.ResourceRef.new("preview", :raster)` instead. Resource references avoid
copying the full pixel payload through each later snapshot and work across local
and remote displays.
