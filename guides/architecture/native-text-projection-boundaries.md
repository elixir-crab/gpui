# Native text projection extension boundaries

This note records the extension points available in the pinned native text stack
before GPUI exposes layout-affecting projection primitives publicly.

## Scope

The desired renderer facts are:

- inline insertions anchored to UTF-16 document positions that consume shaped
  width and participate in wrapping;
- block insertions anchored before or after logical lines that contribute real
  display rows and scroll height;
- deterministic document ↔ visual coordinate mapping while inserted content
  remains outside the Rope, revisions, selections, and undo history.

Application policy such as completion acceptance, notebook execution, language
services, diagnostics, and editor chrome must remain consumer-owned.

## Pinned stack

The native host currently pins:

- GPUI at `1a246efd7e1b83ab568ec5e3e6c1a43a42e1abba`;
- `gpui-component` at `5c5eb1db04dc1146bdec903a8ac74407bd6c2098`.

The latter provides native text-decoration collections, which are sufficient for
foreground style runs because those ranges do not change layout. They are not a
projection mechanism.

## Display-map architecture

`gpui-component`'s editable input uses this pipeline:

```text
Rope buffer positions
  -> WrapMap (soft wrapping)
  -> FoldMap (whole-line visibility)
  -> DisplayMap (buffer/display row conversion)
  -> Input element line shaping and painting
```

`DisplayMap` publicly maps `BufferPoint` and `DisplayPoint`, but its wrapping
input is still the Rope text. It has no insertion layer between buffer text and
wrapping. Consequently it cannot account for external inline text width,
projection-induced wraps, or block rows.

The fold projection only hides interior whole-line wrap rows. It does not render
a placeholder, represent arbitrary intra-line hidden ranges, or expose a public
`InputState` contract for consumer-supplied folds. Hidden ranges therefore remain
deferred separately.

## Inline completion is not a general insertion API

The input's inline-completion path shapes a completion suffix separately and
paints it after the caret. Additional completion lines are painted as ghost rows
and increase a local extra-height value.

This path cannot serve as a neutral inline insertion because:

- it is tied to the focused primary caret and `CompletionProvider` policy;
- state and setters are private to the input implementation;
- only one completion item is represented;
- the first line is painted after layout and does not participate in WrapMap;
- its background intentionally covers existing text;
- hit testing, selection, range geometry, and display mapping do not include it;
- accepting it mutates the document as completion text.

Reusing this path would misrepresent completion mechanics as document projection
and would produce incorrect wrapping and coordinates.

## Block insertions

No public block-decoration or custom-row collection exists in the pinned input.
The input assumes display rows are uniformly one `line_height` tall. Viewport
range calculation divides scroll offsets by that fixed height, and painting zips
shaped lines with visible buffer lines. Inline-completion ghost rows are a local
special case rather than entries in DisplayMap.

A true block insertion therefore needs an explicit row-projection layer that
contributes variable or declared row heights to:

- total scroll extent;
- visible-range lookup;
- line and gutter y offsets;
- caret and range geometry;
- pointer hit testing;
- document/display conversion.

Painting current `GPUI.Text.BlockProjection` overlays cannot satisfy those
requirements and remains intentionally documented as non-layout-affecting.

## Required upstream extension

A suitable native extension should add a projection layer owned by `InputState`,
not by application-specific editor code. A minimal shape would include:

```text
InlineInsertion { id, byte_anchor, text, shaping_style, affinity }
BlockInsertion  { id, line_anchor, placement, height, element/text }
ProjectionSnapshot { stable bounded collections }
```

The display map would become conceptually:

```text
Rope buffer
  -> InlineMap (external shaped insertions)
  -> WrapMap
  -> FoldMap
  -> BlockMap (external rows)
  -> DisplayMap
```

Exact ordering may differ, but all conversion APIs must observe the same
projection snapshot. The native API must also define:

- anchor affinity when edits occur at projection boundaries;
- precedence for overlapping inline insertions;
- mapping a pointer inside insertion content back to a document position;
- selection behavior across insertion content;
- reconciliation without resetting IME, focus, selection, or scroll;
- bounded collection sizes and stable identities;
- behavior under bidi text, ligatures, fallback fonts, and soft wrapping.

## Decision

Do not expose `InlineInsertion` or `BlockInsertion` in Elixir yet. Neither GPUI
nor the pinned `gpui-component` has a public extension that can implement their
claimed layout and coordinate semantics. Do not reuse inline completion, inject
projection text into the Rope, or promote overlay annotations as true rows.

The existing APIs remain truthful:

- `GPUI.Text.InlineProjection` is a visual overlay anchored to geometry;
- `GPUI.Text.BlockProjection` is a visual overlay around a logical line;
- `GPUI.Text.StyleRun` participates in shaping but does not alter text length;
- hidden ranges remain deferred pending a public consumer-fold contract.

Revisit layout-affecting projections when the native input exposes a coherent
projection collection or after a narrowly reviewed upstream contribution adds
one.
