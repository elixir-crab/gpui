# Changelog

## 0.1.1

- Added a neutral controlled two-pane native resizable split with bounded sizes, monotonic resize requests, and consumer-owned persistence.
- Added idiomatic optional `handle_window_event/3` callbacks with `{:close, assigns}` approval, plus declarative native window minimum size and resizability.
- Added stable-ID monotonic focus requests and native focus/blur events for buttons, low-level inputs, controlled inputs, and text surfaces.
- Added opt-in, stable-ID, deduplicated native element-bounds events for composing ordinary HTML/Tailwind-like layout with window-fitted layers.
- Added a neutral bounded `<layer>` primitive backed by GPUI anchored positioning and deferred paint priority, documented as a native top-layer escape hatch while ordinary positioning and static presentation remain HTML/Tailwind-like.
- Added GPUI-native relative and absolute positioning with typed inset utilities, including axis, percentage, fractional, arbitrary-pixel, and auto values.
- Added bounded non-editable block projections anchored before or after logical text lines without changing document coordinates.
- Added bounded non-editable inline text projections anchored to explicit UTF-16 positions without completion policy or Rope mutation.
- Added controlled disabled semantics for generic accessible controls, removing pointer, keyboard, Tab, and AccessKit activation while reporting AccessKit disabled state.
- Added generated accessibility interaction classes and native Tab/Enter/Space activation for simple generic controls, including visible keyboard focus.
- Routed generic accessible Click actions through the same normalized native event helper as pointer activation, with no accessibility-specific Elixir event path.
- Generated native accessibility enums, the grouped semantics struct, decoders, and GPUI conversion matches from the authoritative Elixir accessibility specification.
- Added role-constrained neutral accessibility values, selected/expanded/checked states, and orientation with native AccessKit and remote state-transition coverage.
- Centralized generic accessibility vocabulary, identity, and name/description validation in `GPUI.Accessibility` ahead of role-constrained state attributes.
- Added bounded renderer-independent accessibility roles, labels, and descriptions for identified generic elements, including native AccessKit mapping and remote snapshot coverage.
- Documented the pinned GPUI/AccessKit native accessibility boundary, existing component mappings, truthful schema direction, and unsupported claims.
- Made development reload failures observable and recoverable, with pre-compilation syntax validation and atomic multi-window refresh publishing.
- Preserved dynamic multi-window topology, keys, IDs, per-window assigns, and monotonic allocation across source reload; added end-to-end remote client display reconciliation coverage.
- Hardened remote keyed multi-window snapshots with resume coverage, negotiated `:window_topology_v1`, and bounded window metadata and counts.
- Added Phoenix/OTP-style typed view outcomes for opening and closing keyed windows from `handle_event/3` and `handle_info/2`.
- Added local dynamic multi-window topology with stable application keys, monotonic session IDs, and declarative display reconciliation.
- Added neutral bounded text style runs whose foreground color, weight, and style participate directly in native shaping.
- Added explicit solid, dashed, and wavy underline variants to neutral text decorations.
- Added neutral bounded text decorations with range-attached RGB backgrounds and underlines, without diagnostic or language policy.
- Expanded requested range geometry into bounded per-visual-row rectangles for wrapped text.
- Replaced the editable-text demonstration's fixed gutter with consumer-owned line numbers driven by native visible rows, line height, and scroll offset.
- Added declarative scroll-to-position request tokens and asynchronous native point-to-position hit-test events for text surfaces.
- Added bounded declarative range-geometry requests for text surfaces, limited to 64 ranges and emitted only for currently laid-out content.
- Added revision-tagged, deduplicated text-surface viewport and primary-caret geometry events with public coordinate-space types.
- Added native E2E coverage for two editable surfaces sharing one persistent buffer across local typing, external edits, undo, redo, and reconciliation without external-event echo.
- Added the neutral `<text_surface>` renderer primitive, backed by `GPUI.Text.Buffer`, with native immediate input/IME behavior, focus-request tokens, external revision reconciliation, minimal local text transactions, plural selection events, and selection-only revisions that do not pollute document undo history.
- Added generic persistent native Rope text buffers with explicit UTF-16 positions, revisioned atomic transactions, plural selections, idempotent delivery, stale-revision protection, and monotonic undo/redo, without introducing an opinionated editor component.

- Added GPUI-native flex-basis, overflow clipping, whitespace, text alignment and ellipsis/truncation, and cursor utilities to the Tailwind-compatible style protocol.
- Normalized Tailwind-compatible classes on programmatically constructed `GPUI.UI` component trees before serialization, matching template behavior, and fixed `mix gpui.dev --no-compile` native availability detection.

- Expanded the Tailwind-compatible normalizer with flex shorthands, decimal spacing, fractional and percentage dimensions, safe arbitrary pixel/color/opacity values, exact arbitrary radii, and exact preservation of unsupported classes; replaced static minimum-height styles in the showcase applications with `min-h-0` utilities.

- Added bounded renderer-independent window commands with cross-platform modified shortcuts, native post-dispatch matching that preserves focused input behavior, local/remote event routing, deterministic command tests, and command-driven Git, process, and log/trace dogfood workflows.
- Added renderer-independent controlled field composition, visible help/error feedback, input Enter submission, monotonic native focus requests, deterministic submission testing, and validation-driven Settings Form and external-consumer examples.
- Required semantic names for buttons, checkboxes, text inputs, selectors, comboboxes, popover/menu triggers, and dialogs; propagated controlled values, placeholders, password roles, selected labels, and expanded overlay state into native accessibility metadata.
- Added schema-derived ExDoc option tables and precise named option-map types for every public UI and overlay builder, including required events, defaults, enums, accessibility labels, and named slots.
- Added schema-driven public component attribute and event validation, required owner events for editable controlled components, unknown-option rejection, normalized string event keys, clearer stable-ID errors, corrected schema option types, and expanded common-builder documentation.
- Required semantic labels for switches, radio groups, and sliders; propagated switch state, radio orientation, and slider grouping into native accessibility metadata; and enforced one-based tree accessibility positions at both public and native boundaries.
- Restricted lowercase templates to renderer primitives and added compile-time diagnostics for internal component tags, unsupported tags, and duplicate attributes.
- Made runtime mutation, frame, drain, and injection operations return structured custom-display failures without crashing, while retaining authoritative session state for frame retries.
- Added centralized custom-display callback validation with structured startup, synchronization, drain, and event-injection failures.
- Documented local and remote supervision options and now reject invalid polling intervals and remote session TTLs during startup instead of silently disabling lifecycle behavior.
- Made native compilation an explicit consumer opt-in outside tests, so `GPUI.Test`, renderer-independent sessions, and remote servers compile and run without Rust or a native library.
- Added bounded per-connection and per-session remote request admission, explicit overload errors, caller monitoring, and concurrent 50-session load coverage.
- Moved the remote server, acceptor, connection owners, delegated tasks, session coordinators, and application sessions into explicit OTP supervision subtrees with significant-child shutdown semantics and interruptible deferred mounting.
- Split collection validation, native controls/forms, and dialog/tooltip/popover rendering into focused internal modules while preserving source-derived RustQ renderer routing.
- Hardened native image, raster, text-painting, and IME paths against oversized payloads, arithmetic overflow, malformed selection ranges, and recoverable paint failures.
- Hardened remote lifecycle handling with idempotent mount/event retries, resumable bounded event queues, monitored per-session coordinators, concurrent cross-session dispatch without head-of-line blocking, isolated connection owners, structured display synchronization failures, and stale-timer rejection.
- Hardened internal display frame replies, explicit session callback contracts, event-history consistency, idempotent native window reconciliation, and shared collection keyboard navigation.
- Added accessible source-backed data tables with fixed sortable headers, horizontal scrolling, controlled row/cell navigation, numeric alignment, grid metadata, and 100,000-row native coverage; used by BEAM Observatory for process and ETS inspection.
- Added BEAM Observatory with supervised process and ETS sampling, bounded server-local discovery, asynchronous stale-safe object loading, source-owned models, small table slices, filtering, sorting, and selected-object details.
- Moved option, image, text-child, and style decoding from handwritten Rust into typespec-derived contracts, ordinary Elixir macros, and typed Rusty-Elixir.
- Added Elixir Workbench runtime logs with bounded Logger ingestion, asynchronous stale-safe filtering, pause/follow-tail controls, source-backed semantic log rendering, multiline details, retention rollover, and display-side copying.
- Polished the example suite with clearer controlled-state feedback, filtered and empty process states, safe palette action availability, explicit local/remote path semantics, richer settings review, and modernized resource-reference rendering.
- Added an accessible source-backed monospaced code and unified-diff viewer with line numbers, controlled selection/reveal, horizontal scrolling, tab expansion, display-side copying, and 100,000-line native coverage; used by Elixir Workbench for source and diff previews.
- Consolidated component defaults and native attribute types in the shared schema, normalized explicit nil attributes, indexed renderer metadata in one pass, and derived disabled NIF signatures and generated atom references through RustQ metadata.
- Moved primitive element and event-value decoding into typed Rusty-Elixir and centralized source-backed list/tree mechanics in a handwritten uniform-collection core.
- Added accessible source-backed trees with controlled expansion, hierarchical keyboard navigation, structural accessibility metadata, and 100,000-item native coverage; used by Elixir Workbench for repository navigation.
- Added accessible controlled progress, bounded display-side file selection with operation IDs and remote-safe byte payloads, and display-side clipboard buttons.
- Updated Image Palette to use native file selection, reusable progress, user-side CSS clipboard copying, cancellable analysis, and stale-result-safe replacement.
- Added source-backed virtual-list ranges with overscan, unloaded selection/reveal indexes, coalesced native range events, remote forwarding, and deterministic 100,000-row coverage.
- Added Elixir Workbench with bounded repository scans, source-owned tree/diff models, small snapshot slices, status filtering, runtime logs, diagnostics, command actions, and explicit server-local filesystem semantics.
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
