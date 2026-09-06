# Public API hardening plan

This branch addresses the findings from the read-only public-surface review before the 0.2 API is frozen.

## Phase 1 — package correctness and boundary blockers

- [x] Make desktop testing either genuinely public and packaged or explicitly repository-only.
- [x] Make native-backed model calls fail cleanly when `gpui_native` is absent.
- [x] Make every unpacked package a valid standalone Mix/docs project.
- [x] Give `gpui_components` and `gpui_native` package-owned ExDoc configuration.
- [x] Add exact-payload package/docs regression coverage.

## Phase 2 — explicit stable/advanced/internal surface

- [x] Define and test a supported public module manifest per package.
- [x] Exclude implementation-only modules from public references through `mix.exs` filters while keeping source docs.
- [x] Narrow `GPUI.Native` to a deliberate public API and move raw backend calls internally.
- [x] Separate display implementer contracts from runtime plumbing.
- [x] Narrow remote protocol/transport plumbing while preserving supported advanced hooks.

## Phase 3 — cohesive application/runtime values

- [x] Normalize fallible runtime event-operation result conventions.
- [x] Introduce named typed map contracts for snapshot windows and normalized event payloads while preserving serializable map values.
- [x] Define bounded public runtime error types; timeout configuration remains a follow-up if operations outgrow the current fixed boundary.
- [x] Add a validated dynamic `WindowSpec` construction API.
- [x] Make generated application `child_spec/1` overridable.

## Phase 4 — text API ergonomics and validity

- [x] Add `Transaction` construction/validation helpers and a typed transaction result.
- [x] Add focused range/edit/selection helpers for common operations.
- [x] Make public projection and decoration constructors enforce their advertised invariants.
- [x] Centralize projection, decoration, and style-run validation in their value modules instead of duplicating it in schema code.

## Phase 5 — UI authoring and maintainability

- [x] Narrow default `GPUI.View` imports and make programmatic builders opt-in.
- [x] Define warning/error behavior for unsupported Tailwind classes.
- [x] Add higher-level typed helpers for correlated collection state.
- [x] Keep `GPUI.UI` as the stable facade while extracting form, overlay, collection state, and collection validation into focused implementation modules; defer mechanical per-control splitting until those domains grow independently.
- [x] Clarify native `phx-*` event-attribute naming as an intentional Phoenix-convention vocabulary.

## Phase 6 — package/dependency/documentation polish

- [x] Re-evaluate unconditional `gpui_native -> gpui_components` dependency; keep it deliberately because the package ships both selectable hosts, and document the transitive installation path.
- [x] Re-evaluate optional template/remote/dev dependencies in `gpui`: retain template and remote dependencies as first-class package APIs; make development file watching optional.
- [x] Repair module grouping and document `GPUI.Debug` if supported.
- [x] Make all guides match the final stable/advanced/internal contract.
- [x] Run formatter, focused tests, exact package checks, docs checks, and `mix ci`.
