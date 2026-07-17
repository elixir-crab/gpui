# Image palette

This application loads a local image, extracts dominant colors, and exports the
result as CSS custom properties.

Run it with an optional image path:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/image_palette/run.exs -- path/to/image.png
```

You can also enter or replace the path in the running application. PNG, JPEG,
WebP, GIF, TIFF, BMP, and ICO formats are accepted.

## Architecture

The example keeps each responsibility explicit:

- `Examples.ImagePalette.View` owns controlled paths, progress, palette
  selection, and status;
- `Examples.ImagePalette.Coordinator` subscribes to runtime updates and turns
  load/export events into supervised tasks;
- `GPUI.Image` decodes encoded bytes on a dirty CPU scheduler;
- `Examples.ImagePalette.Analysis` samples pixels, quantizes colors, and builds
  a bounded preview raster;
- the preview is installed once as a `GPUI.ResourceRef`, rather than copied into
  every later snapshot;
- stale work is cancelled and progress returns through acknowledged
  `GPUI.Runtime.send_view/3` messages.

The palette algorithm samples at most about 80,000 pixels, groups colors into
4-bit RGB bins, and sorts deterministically by frequency and color. The preview
is resized to fit within 520 × 420 pixels before being sent to the display.

CSS export produces variables such as:

```css
:root {
  --palette-1: #2563EB;
  --palette-2: #0F172A;
}
```
