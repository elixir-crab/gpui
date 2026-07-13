# Changelog

## 0.1.0-rc

Initial release candidate.

- Renderer-independent `GPUI.Session` and typed `GPUI.Snapshot` boundaries.
- Local native and remote TCP displays with isolated application sessions.
- One process-global GPUI application loop with acknowledged window lifecycle commands.
- HEEx-style templates and a constrained Tailwind-compatible style normalizer.
- Native input, raster resources, resource references, and interactive events.
- RustQ-generated Rustler exports, Elixir stubs, component metadata, and style dispatch.
- Structured ExUnit E2E coverage under Xvfb/Lavapipe, including pointer, editing, clipboard, controlled-input, and window-close interaction.
- Linux CI quality/release gates and an attested, checksummed x86-64 precompiled-NIF release pipeline.
