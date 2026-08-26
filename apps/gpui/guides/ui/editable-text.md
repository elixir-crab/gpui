# Editable text surfaces

`<text_surface>` is a neutral, revisioned text editor primitive backed by a
persistent `GPUI.Text.Buffer`. It provides native keyboard, IME, selection,
undo, scrolling, shaping, hit testing, and geometry mechanics without adding
file, language, syntax, gutter, tab, completion, or IDE policy.

Use `GPUI.UI.input/1` for ordinary controlled single-line form fields. Use
`<text_surface>` when text needs persistent Rope storage, revisioned external
edits, native undo and redo, multiline composition, or document geometry.

For implementation ownership and deferred projection work, see
[Editable text internals](editable-text-internals.html) and
[Native text projections](text-projections.html).

## Create and mount a buffer

Create the buffer when mounting the application and retain it in view assigns:

```elixir
alias GPUI.Text.Buffer

{:ok, buffer} = Buffer.new("# Notes\n\nEdit me with native keyboard input.\n")

assigns = %{
  buffer: buffer,
  revision: 0,
  focus_request: 1
}
```

Render the persistent resource directly:

```elixir
<text_surface
  id="document"
  buffer={assigns.buffer}
  focus_request={assigns.focus_request}
  soft_wrap={true}
  tab_size={2}
  phx-transaction="document-transaction"
  phx-selection-change="document-selection"
  class="grow min-h-0 p-3 bg-slate-900 text-sm"
/>
```

The stable component ID retains surface interaction state across ordinary
rerenders. The buffer owns the current Rope text, revision, selections, and
history independently of any one mounted surface. Multiple surfaces may refer
to the same buffer.

Native editing updates the buffer before emitting `phx-transaction`, so a
keystroke does not wait for a BEAM round trip before repainting. The event's
`value` is the applied `GPUI.Text.Transaction`, and the top-level `revision` is
the resulting buffer revision:

```elixir
def handle_event(
      "document-transaction",
      %{value: transaction, revision: revision},
      assigns
    ) do
  persist_or_forward(transaction)
  {:noreply, %{assigns | revision: revision}}
end
```

The application may persist, acknowledge, or forward the transaction. It should
not replay the already-applied local transaction into the same buffer.

## Positions, ranges, and selections

Public text positions are zero-based `{line, utf16_offset}` values:

```elixir
position = GPUI.Text.Position.new(3, 12)
range = GPUI.Text.Range.new(GPUI.Text.Position.new(1, 0), position)
selection = GPUI.Text.Selection.caret("primary", position, primary: true)
```

Offsets count UTF-16 code units within the logical line. This matches LSP-style
coordinates but is not a grapheme or UTF-8 byte index. Positions in the middle
of a surrogate pair, beyond a line, or inside a CRLF line ending are rejected.
Combining code points remain independently addressable.

Transactions and events represent selections as a list. The current native
surface supports one primary selection; the plural protocol leaves room for
future multi-selection mechanics without changing the transaction shape.
Selection-only movement advances the buffer revision but does not add a document
edit to undo history.

## External edits

Application code changes text through the same revisioned transaction model:

```elixir
alias GPUI.Text.{Buffer, Edit, Position, Range, Selection, Transaction}

{:ok, snapshot} = Buffer.snapshot(buffer)
insert_at = Position.new(0, 0)

transaction = %Transaction{
  id: "prepend-title-#{System.unique_integer([:positive])}",
  base_revision: snapshot.revision,
  origin: :external,
  edits: [Edit.new(Range.new(insert_at, insert_at), "Title\n")],
  selections: [Selection.caret("primary", Position.new(1, 0), primary: true)]
}

{:ok, %{revision: revision}} = Buffer.transact(buffer, transaction)
```

A transaction has a stable non-empty ID, the exact current base revision,
non-overlapping edits, and the complete resulting selection list. All edits are
applied atomically against the same base text.

Repeating an identical transaction ID and payload is idempotent. Reusing an ID
with different content returns a conflict, and applying against an old revision
returns a stale-revision error. Take a fresh snapshot and reconcile application
intent rather than silently overwriting newer text.

A mounted surface observes successful external edits through the shared buffer
revision. External transactions, undo, and redo are not echoed as local
`phx-transaction` events.

## Snapshots, undo, and redo

A snapshot contains the current text, revision, selections, and history
availability:

```elixir
{:ok, snapshot} = Buffer.snapshot(buffer)

if snapshot.can_undo do
  {:ok, updated} = Buffer.undo(buffer, snapshot.revision)
end
```

Redo follows the same base-revision contract:

```elixir
{:ok, snapshot} = Buffer.snapshot(buffer)
{:ok, updated} = Buffer.redo(buffer, snapshot.revision)
```

Undo and redo create new monotonic revisions. They never roll the revision
number backward. File saving, dirty state, conflict presentation, and command
routing remain application concerns.

## Submission and auto-growing composers

A surface can act as a bounded multiline composer:

```elixir
<text_surface
  id="composer"
  buffer={assigns.draft_buffer}
  focus_request={assigns.composer_focus_request}
  soft_wrap={true}
  auto_grow={true}
  min_lines={2}
  max_lines={6}
  submit_policy="submit"
  phx-transaction="draft-transaction"
  phx-submit="submit-draft"
  class="w-full p-3 bg-slate-800 rounded-lg text-sm"
/>
```

With `submit_policy="submit"`, plain Enter emits `phx-submit` with the current
buffer text and does not insert a newline. Shift+Enter remains an ordinary edit.
The policy requires a non-empty `phx-submit`. Submission does not clear the
buffer; the application must apply an external transaction after accepting the
value.

The default `submit_policy="newline"` treats Enter as editing. With `auto_grow`,
the intrinsic height follows wrapped rows from `min_lines` through `max_lines`,
then retains native internal scrolling. Both line bounds must be positive, at
most 64, and satisfy `min_lines <= max_lines`.

## Focus and scrolling requests

Native focus is transient state, not an application-controlled boolean.
Increment `focus_request` to request focus once:

```elixir
{:noreply, %{assigns | focus_request: assigns.focus_request + 1}}
```

Reusing the same token does not steal focus during later rerenders. Optional
`phx-focus` and `phx-blur` events report actual native focus changes.

To move the primary caret and reveal a logical position, update both
`scroll_to` and a monotonic `scroll_request`:

```elixir
<text_surface
  id="document"
  buffer={assigns.buffer}
  scroll_to={assigns.scroll_to}
  scroll_request={assigns.scroll_request}
/>
```

This request changes selection and visibility through native input mechanics; it
does not change document text.

## Viewport, caret, range, and hit-test geometry

Geometry events are optional and asynchronous. They are emitted only after
native layout exists, are tagged with the buffer revision, and are deduplicated
while their bounded values remain unchanged.

```elixir
<text_surface
  id="document"
  buffer={assigns.buffer}
  geometry_ranges={assigns.geometry_ranges}
  phx-viewport-change="viewport-changed"
  phx-geometry-change="caret-changed"
  phx-range-geometry-change="ranges-changed"
  phx-hit-test="hit-tested"
/>
```

Decode event values with the public structs:

```elixir
def handle_event("viewport-changed", %{value: value}, assigns) do
  viewport = GPUI.Text.Viewport.from_event(value)
  {:noreply, %{assigns | first_visible_row: viewport.first_visible_row}}
end

def handle_event("caret-changed", %{value: value}, assigns) do
  caret = GPUI.Text.CaretGeometry.from_event(value)
  {:noreply, %{assigns | caret: {caret.line, caret.utf16_offset}}}
end

def handle_event("ranges-changed", %{value: values}, assigns) do
  ranges = Enum.map(values, &GPUI.Text.RangeGeometry.from_event/1)
  {:noreply, %{assigns | range_geometry: ranges}}
end
```

`GPUI.Text.Viewport` reports visible visual rows, line height, and native scroll
offsets. `GPUI.Text.CaretGeometry` reports the primary caret's logical position
and window-relative native-pixel rectangle. Up to 64 requested
`geometry_ranges` return at most 256 visual rectangles per range. `phx-hit-test`
reports the logical UTF-16 position selected by native pointer hit testing.

Do not use geometry events as synchronous layout queries or infer document text
from pixels.

## Decorations, shaping, and projections

The application can attach bounded presentation data while retaining parser,
language, diagnostic, completion, and product policy:

```elixir
<text_surface
  id="document"
  buffer={assigns.buffer}
  decorations={assigns.decorations}
  style_runs={assigns.style_runs}
  inline_projections={assigns.inline_projections}
  block_projections={assigns.block_projections}
/>
```

- Up to 256 `GPUI.Text.Decoration` values add backgrounds or solid, dashed, and
  wavy underlines to logical ranges.
- Up to 512 `GPUI.Text.StyleRun` values add foreground color, font weight, and
  font style before native shaping.
- Up to 128 `GPUI.Text.InlineProjection` values attach bounded non-editable text
  to logical positions.
- Up to 64 `GPUI.Text.BlockProjection` values attach bounded before/after-line
  overlays.

Decorations and style runs do not alter text, selections, revisions, or history.
Projection text does not enter the Rope or change document coordinates. Current
inline and block projections are presentation annotations; they do not provide
a general layout-affecting display map. Arbitrary hidden ranges remain deferred.

## Testing

Test buffer transactions directly when behavior does not require a mounted
surface:

```elixir
assert {:ok, buffer} = GPUI.Text.Buffer.new("one two")
assert {:ok, %{revision: 0, text: "one two"}} = GPUI.Text.Buffer.snapshot(buffer)
```

Use ordinary `GPUI.Test` to assert declarative attributes and application event
handling. Use deterministic native tests for real input, focus, selection,
submission, geometry, and reconciliation mechanics. Use desktop E2E only for
operating-system keyboard, IME, clipboard, focus, or platform-window behavior.

See `examples/features/editable_text_surface.exs` for geometry, decorations,
external edits, undo, redo, scrolling, and an application-owned gutter. See
`examples/features/rich_transcript.exs` for a bounded submit composer.
