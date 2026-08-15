# Editable text primitives

GPUI exposes editable text as neutral model and renderer primitives. It does not
provide an IDE, editor shell, document tab, language client, gutter, completion
menu, or `UI.code_editor` component. Consumers compose those policies from the
same low-level elements used by other applications.

## Design sources and licensing

The design follows useful architectural lessons from Zed's `text`, `editor`,
`multi_buffer`, selection, and display-map code without depending on those
crates. Zed's GPUI crate is Apache-2.0, while its `text`, `editor`, `language`,
`project`, and `multi_buffer` crates are GPL-3.0-or-later. Importing the latter
would change the distribution obligations of this library.

The pinned Apache-2.0 `gpui-component` input implementation provides useful
implementation machinery: Rope text, native input and IME, edit history,
selection painting, scrolling, search, folding, highlighting, and decoration
painting. Its convenience `InputState::code_editor` API and embedded language
provider assumptions do not define GPUI's public Elixir API.

## Ownership boundary

Elixir owns application policy:

- document identity, file persistence, dirty state, and conflict handling;
- projects, tabs, pane topology, commands, and keymaps;
- parser and language-service processes;
- diagnostics, completions, navigation, formatting, and workspace edits.

Native state owns latency-sensitive mechanics:

- Rope text storage and monotonic revisions;
- immediate edits, selections, undo, and redo;
- later, IME composition, shaping, hit testing, and viewport geometry.

A keystroke must not wait for a BEAM round trip before the native surface can
repaint. The BEAM receives revisioned transactions and can acknowledge, persist,
or reconcile them asynchronously.

## Coordinate system

Protocol positions are zero-based `{line, utf16_offset}` values. The offset is a
UTF-16 code-unit offset within the logical line and excludes its line ending.
This matches LSP coordinates while allowing the native implementation to keep
byte offsets internally.

Conversions must reject:

- missing lines;
- columns beyond the logical line;
- positions in the middle of a surrogate pair;
- ranges whose end precedes their start;
- overlapping edits in one transaction.

CRLF is one logical line ending. Its carriage return is not addressable as line
content. Combining code points remain independently addressable because UTF-16
coordinates do not imply grapheme coordinates; renderer hit testing may clamp
to grapheme boundaries separately.

## Model protocol

The neutral model consists of:

- `GPUI.Text.Position`
- `GPUI.Text.Range`
- `GPUI.Text.Edit`
- `GPUI.Text.Selection`
- `GPUI.Text.Transaction`
- `GPUI.Text.Snapshot`
- `GPUI.Text.Buffer`

Selections are plural from protocol version one even though the first native
implementation supports a single primary selection. This avoids replacing the
protocol when multi-cursor editing is introduced.

A transaction has a stable ID, a required base revision, an origin, atomic
non-overlapping edits, and the complete post-transaction selection set. A
successful transaction increments the revision exactly once. Repeating the same
transaction ID with the same payload is idempotent; reusing it for different
content is rejected. A transaction based on any other revision is stale.

Undo and redo are new monotonic revisions, never revision rollback. External
edits use the same transaction mechanism as local edits and therefore preserve a
single consistency model.

## First milestone

The first milestone intentionally has no visual surface. It provides a
persistent native Rope resource with:

- snapshots;
- atomic revisioned edits;
- one primary selection represented as a list;
- bounded undo and redo history;
- stale-revision and duplicate-delivery handling;
- UTF-16/byte conversion with Unicode and CRLF coverage.

It does not know about files, saving, languages, syntax highlighting, or IDEs.

## Renderer primitive

The low-level `<text_surface>` primitive refers directly to a persistent
`GPUI.Text.Buffer`. It keeps immediate keyboard and IME changes native, updates
the Rope before notifying Elixir, and emits revisioned transaction and plural
selection events. Selection-only movement advances the shared buffer revision but
does not create document undo entries or clear redo history. A monotonically
changing `focus_request` value requests focus without turning focus into
application-owned boolean state.

The primitive accepts generic input behavior such as soft wrapping, whitespace
display, tab width, hard tabs, and disabled state. With `auto_grow`, bounded
`min_lines` and `max_lines` select the native input's intrinsic wrapped-row
height; after `max_lines` it retains native internal scrolling. The bounds are
part of the declarative snapshot and must satisfy `min_lines <= max_lines`.

`submit_policy="newline"` leaves Enter and Shift+Enter as ordinary edits.
`submit_policy="submit"` requires `phx-submit` and makes plain Enter emit that event
with the current buffer text without inserting a newline, while Shift+Enter
continues to insert one. Submission uses the native input action path, so active
IME composition is handled by the input before application submission; Elixir
remains responsible for clearing or otherwise mutating the buffer afterward.

It deliberately does not live
under `GPUI.UI` and does not render line numbers, tabs, diagnostics, completion
menus, or status bars. External buffer transactions, undo, and redo are
reconciled into a mounted surface from the buffer revision without echoing them
as local input.

The first geometry contract emits revision-tagged, deduplicated viewport and
primary-caret facts through optional `phx-viewport-change` and
`phx-geometry-change` events. `GPUI.Text.Viewport` reports visible visual rows
and native scroll offsets; `GPUI.Text.CaretGeometry` reports zero-based UTF-16
logical position plus window-relative native pixel bounds. Geometry is emitted
only after layout exists and only when its bounded value changes.

The first bounded request contract accepts up to 64 declarative
`geometry_ranges` and emits currently laid-out bounds through
`phx-range-geometry-change`. `GPUI.Text.RangeGeometry` preserves the requested
logical range and reports a bounded `GPUI.Text.Rectangle` for every visual row
crossed by wrapped text. Results remain limited to 64 requested ranges and 256
rectangles per range.

A monotonically increasing `scroll_request` token paired with `scroll_to` moves
the native primary caret to an explicit UTF-16 position and lets the existing
native input machinery reveal it without changing document text. Optional
`phx-hit-test` events report the post-click logical UTF-16 position selected by
native text hit testing. Neither contract introduces synchronous pointer NIF
traffic.

The first decoration contract accepts up to 256 `GPUI.Text.Decoration` values.
Each decoration attaches an optional RGB background and/or solid, dashed, or
wavy RGB underline to a logical UTF-16 range. Native painting uses current
layout geometry while the consumer retains diagnostic severity, language,
message, command, and service policy. Decorations do not alter text, selections,
revisions, or history.

A separate shaping contract accepts up to 512 `GPUI.Text.StyleRun` values.
Each run carries optional RGB foreground color, font weight, and font style for
a logical UTF-16 range. Runs are converted to native byte ranges and composed
into GPUI Component's text-decoration collections before line shaping, so font
fallback, ligatures, wrapping, bidi layout, and glyph metrics use the styled
runs directly. They are not painted as duplicate glyph overlays. Consumer code
retains syntax, language, token, and diagnostic policy.

The first projection contract accepts up to 128 bounded
`GPUI.Text.InlineProjection` values, each containing at most 4096 bytes. A
projection anchors non-editable display text and an RGB color to an explicit
UTF-16 position. Projection text never enters the Rope, changes selection
coordinates, participates in history, or implies completion behavior.

The block projection contract accepts up to 64 bounded
`GPUI.Text.BlockProjection` values containing at most 16384 bytes. Blocks are
anchored before or after a logical line and carry explicit height, foreground,
and optional background colors. They are overlay annotations: they do not add
rows to native text layout or alter document coordinates. Consumers can use
them for notes and previews while retaining application policy.

The demonstration's gutter is now entirely consumer-owned: Elixir derives the
visible line-number elements, row heights, and fractional vertical offset from
`GPUI.Text.Viewport`. The renderer still exposes no gutter or editor shell.

The feature demonstration includes application-owned external edit, undo, and
redo controls so reconciliation can be exercised without treating persistence
or document commands as renderer policy.

## Later renderer primitives

Independent projection inputs will eventually cover:

- ranged decorations;
- hidden ranges;
- inline insertions;
- block insertions;
- visual-row and viewport geometry;
- caret and range bounds;
- point-to-position hit testing.

True layout-affecting inline and block insertions remain deferred. The pinned
native input has no projection collection that participates consistently in
wrapping, scroll extent, geometry, hit testing, and document/display mapping;
see [Native text projection extension boundaries](native-text-projection-boundaries.md).

Consumers can use those inputs to build code editors, prose editors, notebooks,
diff tools, terminal prompts, or domain-specific annotated text surfaces without
adopting library-owned IDE policy.
