# Text and editing

Text primitives preserve renderer-independent content and coordinates while the
native display owns transient selection, shaping, and interaction mechanics. For
revisioned editable surfaces, see
[Editable text surfaces](editable-text.html). Implementation details remain in
[Editable text internals](editable-text-internals.html).

## Rich selectable text

`rich_text/1` renders consumer-produced text and shaping runs without moving
Markdown, HTML, syntax, or product policy into the native display. Elixir owns
parsing and supplies plain UTF-8 text plus sorted, non-overlapping
`GPUI.Text.RichRun` values:

```elixir
alias GPUI.Text.{Position, Range, RichRun}

runs = [
  RichRun.new(
    Range.new(Position.new(0, 0), Position.new(0, 7)),
    font_weight: :bold,
    color: 0xF8FAFC
  ),
  RichRun.new(
    Range.new(Position.new(1, 0), Position.new(1, 12)),
    color: 0x60A5FA,
    underline: 0x60A5FA,
    link: "message://details"
  )
]

<UI.rich_text
  id="message-body"
  label="Message"
  text={assigns.text}
  runs={runs}
  phx-link="open_link"
  class="text-slate-300 leading-6"
/>
```

Run positions use zero-based `{line, utf16_offset}` coordinates and are
converted to native UTF-8 shaping ranges without splitting surrogate pairs.
Runs can set foreground/background color, font weight/style, solid or wavy
underline, strikethrough, and an opaque bounded link value. Unstyled gaps
inherit ordinary component text styles.

Selection is transient native state. Pointer dragging paints selection, the
platform select-all and copy shortcuts operate on it, Escape clears it, and a
pointer press outside the component discards it. Retained content keeps an
unchanged selected byte range across ordinary rerenders and streaming appends;
changing the selected bytes or removing the stateful component discards the
selection.

A link requires `phx-link` and emits its opaque value as an ordinary `:link`
event; the framework does not open URLs or interpret schemes. Linked rich text
is one native Tab stop. Left/Up and Right/Down navigate links in document order,
and Enter or Space uses the same typed event path as pointer activation.
AccessKit currently exposes the continuous value as `Role::Document` with a
synthetic `Role::TextRun`, character lengths, and directional selection facts.
Per-link AccessKit actions remain unsupported because pinned GPUI does not
provide public action listeners for synthetic child node IDs; the framework
does not advertise synthetic clickable links it cannot activate truthfully.

Rich text is bounded to
1 MiB and 2,048 runs and is serialized normally for local, test, and remote
displays.
