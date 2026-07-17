# Changelog

## 0.1.1

- Added accessible controlled progress, bounded display-side file selection with operation IDs and remote-safe byte payloads, and display-side clipboard buttons.
- Updated Image Palette to use native file selection, reusable progress, and user-side CSS clipboard copying.
- Added accessible virtualized uniform-height collections with stable row identities, controlled selection, keyboard navigation, and programmatic reveal.
- Added common image decoding into `GPUI.Raster` values and a supervised image-palette application with progress, bounded previews, resource reuse, and CSS export.
- Upgraded generation to RustQ `1.0.0-rc.3` and migrated compiled `defrust` access to the documented `RustQ.Meta.AST` API.
- Derived native atoms, resources, event values and kinds, renderer routing, disabled-feature NIFs, and boundary policy structurally through RustQ and Rust source metadata.
- Moved window and component term decoding into typed Rusty-Elixir `defrust` helpers.
- Added alias-aware component tags, HEEx named slots, and controlled `GPUI.UI.Overlay.popover/1` with keyboard and dismissal focus behavior.
- Added `GPUI.UI.Overlay.tooltip/1` with textual named-slot content, configurable native show delay, and hoverable lifecycle support.
- Added controlled `GPUI.UI.Overlay.dialog/1` with arbitrary GPUI content, optional triggers, focus trapping/restoration, keyboard and overlay dismissal, and local/remote native coverage.
- Added controlled `GPUI.UI.Overlay.dropdown_menu/1` with named items, native popup-menu selection, disabled and checked states, controlled dismissal, and local/remote coverage.
- Added process-global light and dark component theme switching across native displays.
- Added controlled `GPUI.UI.input/1` with stable native entity reconciliation.
- Added native coverage for input editing, rerendering, and theme changes.
- Added packaged `GPUI.Test` ExUnit helpers and `GPUI.Test.Display` for consumer tests.
- Added a typed persistent native component registry with structural duplicate-ID validation.
- Added controlled `GPUI.UI.select/1`, native popup interaction, and semantic test support.
- Generated native component contracts, element variants, decoder/render dispatch, and state-registry accessors from the component schema.
- Added persistent `GPUI.UI.combobox/1` with search events, dynamic filtering, clearing, and local/remote native coverage.
- Added controlled `GPUI.UI.slider/1` with generated numeric contracts, change/release events, persistent reconciliation, and native coverage.
- Added controlled `GPUI.UI.tabs/1` backed directly by `gpui-component` tab bars.
- Added controlled `GPUI.UI.accordion/1` and `accordion_item/1` with arbitrary nested GPUI content.
- Split advanced native component renderers by responsibility and expanded local/remote lifecycle coverage.
- Added controlled `GPUI.UI.switch/1` and `radio_group/1` with disabled radio options and local/remote native coverage.
- Added Switch Enter/Space activation, Radio Group arrow navigation with disabled-option skipping, roving tab stops, and visual Switch loading feedback.
- Added monitored local-runtime and remote-client update subscriptions with typed revisions, normalized events, and synchronized snapshots.
- Added generation-based native frame barriers for local and remote displays without blocking runtime message processing.
- Added completed-frame tokens for deterministic synchronization of native-only hover, focus, tooltip, and input transitions.
- Added deterministic Xvfb visual captures for components and overlays, plus explicit single-purpose screenshot helpers.
- Replaced E2E state polling and sleep-based synchronization with monitored update messages, frame barriers, and mailbox assertions.
- Added structured ExDoc guides and replaced the long-form README with a concise project introduction.
- Preserved upstream component style defaults and constrained full-size Select, Combobox, and Slider controls to their intended layout heights.

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
