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
display, tab width, hard tabs, and disabled state. It deliberately does not live
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
logical range and reports its window-relative bounding rectangle. Wrapped
ranges currently produce one enclosing rectangle; per-visual-row rectangles
remain a later extension.

A monotonically increasing `scroll_request` token paired with `scroll_to` moves
the native primary caret to an explicit UTF-16 position and lets the existing
native input machinery reveal it without changing document text. Optional
`phx-hit-test` events report the post-click logical UTF-16 position selected by
native text hit testing. Neither contract introduces synchronous pointer NIF
traffic.

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

Consumers can use those inputs to build code editors, prose editors, notebooks,
diff tools, terminal prompts, or domain-specific annotated text surfaces without
adopting library-owned IDE policy.
