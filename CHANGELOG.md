# Changelog

## 0.1.1

- Hardened native image, raster, text-painting, and IME paths against oversized payloads, arithmetic overflow, malformed selection ranges, and recoverable paint failures.
- Hardened remote lifecycle handling with idempotent mount/event retries, resumable bounded event queues, monitored per-session coordinators, concurrent cross-session dispatch without head-of-line blocking, isolated connection owners, structured display synchronization failures, and stale-timer rejection.
- Hardened internal display frame replies, explicit session callback contracts, event-history consistency, idempotent native window reconciliation, and shared collection keyboard navigation.
- Added accessible source-backed data tables with fixed sortable headers, horizontal scrolling, controlled row/cell navigation, numeric alignment, grid metadata, and 100,000-row native coverage; migrated Process Explorer to the shared table.
- Added a supervised ETS Table Explorer with bounded server-local discovery, asynchronous stale-safe object loading, source-owned models, small table slices, filtering, sorting, and selected-object details.
- Moved option, image, text-child, and style decoding from handwritten Rust into typespec-derived contracts, ordinary Elixir macros, and typed Rusty-Elixir.
- Added a supervised OTP log and trace explorer with bounded Logger ingestion, asynchronous stale-safe filtering, pause/follow-tail controls, source-backed semantic log rendering, multiline details, retention rollover, and display-side copying.
- Polished the example suite with clearer controlled-state feedback, filtered and empty process states, safe palette action availability, explicit local/remote path semantics, richer settings review, and modernized resource-reference rendering.
- Added an accessible source-backed monospaced code and unified-diff viewer with line numbers, controlled selection/reveal, horizontal scrolling, tab expansion, display-side copying, and 100,000-line native coverage; migrated Git Repository Browser previews to it.
- Consolidated component defaults and native attribute types in the shared schema, normalized explicit nil attributes, indexed renderer metadata in one pass, and derived disabled NIF signatures and generated atom references through RustQ metadata.
- Moved primitive element and event-value decoding into typed Rusty-Elixir and centralized source-backed list/tree mechanics in a handwritten uniform-collection core.
- Added accessible source-backed trees with controlled expansion, hierarchical keyboard navigation, structural accessibility metadata, and 100,000-item native coverage; migrated the Git Repository Browser to tree semantics.
- Added accessible controlled progress, bounded display-side file selection with operation IDs and remote-safe byte payloads, and display-side clipboard buttons.
- Updated Image Palette to use native file selection, reusable progress, user-side CSS clipboard copying, cancellable analysis, and stale-result-safe replacement.
- Added source-backed virtual-list ranges with overscan, unloaded selection/reveal indexes, coalesced native range events, remote forwarding, and deterministic 100,000-row coverage.
- Added a supervised Git Repository Browser with bounded scans, source-owned tree/diff models, small snapshot slices, status filtering, and explicit server-local filesystem semantics.
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
