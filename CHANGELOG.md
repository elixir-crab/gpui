# Changelog

## 0.1.1

- Added process-global light and dark component theme switching across native displays.
- Added controlled `GPUI.UI.input/1` with stable native entity reconciliation.
- Added native coverage for input editing, rerendering, and theme changes.
- Added packaged `GPUI.Test` ExUnit helpers and `GPUI.Test.Display` for consumer tests.
- Added a typed persistent native component registry with structural duplicate-ID validation.
- Added controlled `GPUI.UI.select/1`, native popup interaction, and semantic test support.
- Generated native component contracts and decoders from the component schema.
- Added persistent `GPUI.UI.combobox/1` with search events, dynamic filtering, clearing, and local/remote native coverage.
- Added controlled `GPUI.UI.slider/1` with generated numeric contracts, change/release events, persistent reconciliation, and native coverage.
- Added controlled `GPUI.UI.tabs/1` backed directly by `gpui-component` tab bars.
- Added controlled `GPUI.UI.accordion/1` and `accordion_item/1` with arbitrary nested GPUI content.
- Split advanced native component renderers by responsibility and expanded local/remote lifecycle coverage.

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
