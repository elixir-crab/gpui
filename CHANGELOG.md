# Changelog

## 0.1.0

- Added controlled `GPUI.UI` button and checkbox controls backed by `gpui-component`.
- Added application-wide component assets, initialization, root wrapping, and theme defaults.
- Added local and remote native interaction coverage for component rendering and events.

## 0.1.0-rc

Initial release candidate.

- Renderer-independent `GPUI.Session` and typed `GPUI.Snapshot` boundaries.
- Local native and remote TCP displays with isolated application sessions.
- One process-global GPUI application loop with acknowledged window lifecycle commands.
- HEEx-style templates and a constrained Tailwind-compatible style normalizer.
- Native input, raster resources, resource references, and interactive events.
- RustQ 0.11-generated Rustler exports, Elixir stubs, component metadata, and style dispatch.
- Structured ExUnit E2E coverage under Xvfb/Lavapipe, including pointer, editing, clipboard, controlled-input, and window-close interaction.
- Isolated fast, RustQ freshness, native E2E, and release validation environments.
- Linux CI quality/release gates and an attested, checksummed x86-64 precompiled-NIF release pipeline.
