# Image palette

This application loads a local image, extracts dominant colors, and exports the
result as CSS custom properties.

Run it with an optional image path:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/image_palette/run.exs -- path/to/image.png
```

Use the native **Choose image** action to select or replace the image while the
application is running. Active analysis can be cancelled or replaced without
allowing stale task results to overwrite the newer state. The display reads
bounded file bytes rather than returning a client-local path, so selection also
has useful remote-display semantics. PNG, JPEG, WebP, GIF, TIFF, BMP, and ICO
formats are accepted.

## Architecture

The example keeps each responsibility explicit:

- `Examples.ImagePalette.View` owns controlled file-selection status, progress,
  palette selection, and export state;
- `Examples.ImagePalette.Coordinator` subscribes to runtime updates and turns
  load/export events into supervised tasks;
- `GPUI.Image` decodes encoded bytes on a dirty CPU scheduler;
- `Examples.ImagePalette.Analysis` samples pixels, quantizes colors, and builds
  a bounded preview raster;
- the preview is installed once as a `GPUI.ResourceRef`, rather than copied into
  every later snapshot;
- stale work is cancelled and progress returns through acknowledged
  `GPUI.Runtime.send_view/3` messages;
- `GPUI.UI.progress/1`, `file_picker/1`, and `copy_button/1` keep progress,
  platform selection, and clipboard behavior reusable.

The palette algorithm samples at most about 80,000 pixels, groups colors into
4-bit RGB bins, and sorts deterministically by frequency and color. The preview
is resized to fit within 520 × 420 pixels before being sent to the display.

CSS can be written to the application-side export path or copied directly to
the display-side clipboard. Exported variables look like:

```css
:root {
  --palette-1: #2563EB;
  --palette-2: #0F172A;
}
```
