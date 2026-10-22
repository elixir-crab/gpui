# Text and editing

Text primitives preserve renderer-independent content and coordinates while the
native display owns transient selection, shaping, and interaction mechanics. For
revisioned editable surfaces, see
[Editable text surfaces](editable-text.html). Implementation details remain in
[Editable text internals](editable-text-internals.html).

## Application-owned terminals

`GPUI.Terminal.surface/1` is a fixed-cell display and input boundary, not a
terminal emulator or editable text field. The application owns the escape
parser, retained rows, terminal modes, PTY/SSH lifecycle, and key encoding.
Both vanilla and component-capable hosts implement the `terminal` extension.

```elixir
GPUI.Terminal.surface(%{
  id: "console",
  label: "Remote console",
  columns: 80,
  rows: [
    [%{text: "ready ", columns: 6, color: {:rgb, 0x80CC90}},
     %{text: "界", columns: 2}]
  ],
  cursor_row: 0,
  cursor_column: 8,
  focus_request: 1,
  "phx-keystroke": "terminal-key",
  "phx-text": "terminal-text",
  "phx-paste": "terminal-paste",
  "phx-resize": "terminal-size",
  "phx-range": "terminal-visible"
})
```

Rows are ordered oldest first. Runs can combine printable ASCII cells; wide,
combining, or fallback graphemes occupy individual one- or two-column runs.
They can specify foreground/background, normal/bold weight, and normal/italic
style. Every glyph is placed on the measured grid with ligatures disabled.
The cursor is separate paint, never a character in selectable/copied text.
Keep `reset_request` stable across ordinary rerenders and increment it when
replacing the terminal session. It clears native scroll/selection/composition.

Events deliberately separate three input sources:

- `:keystroke`: `%{key: key, control: boolean, alt: boolean, shift: boolean,
  platform: boolean, repeat: boolean}` for editing/navigation/control/meta keys.
- `:text`: committed Unicode text. IME preedit remains native and is not sent
  to the application until committed. Do not reconstruct a local input line.
- `:paste`: clipboard text with tabs and newlines intact. The application
  decides paste confirmation and terminal-mode/bracketed-paste encoding.

Printable keys are not emitted a second time as keystrokes. Platform shortcuts
other than select-all/copy/paste remain application commands. On non-macOS
hosts, Control-Shift-C/V also copy/paste. Native mouse selection copies retained
rows; scrolling and Shift-PageUp/PageDown browse history. Shift-End or typing
returns to the tail. Small trackpad deltas accumulate rather than disappearing.

`:resize` reports `%{columns: integer, rows: integer, cell_width: number,
cell_height: number}` using actual font shaping and viewport dimensions.
Zero-sized hidden surfaces do not request a resize. `:range` optionally reports
the exclusive `{first, last}` visible row range as the ordinary range event map.
Do not estimate font widths or feed hidden geometry to a remote PTY.

Override `font_family` when desired; the defaults are Menlo on macOS, Consolas
on Windows, and DejaVu Sans Mono on other platforms, not the proportional UI font.

The public boundary limits snapshots to 10,000 retained rows, 512 columns,
and 8 MiB of text. These are display bounds, not application scrollback policy.
The native host paints only visible rows; no remote bytes, escape sequence, or
clipboard text is executed by GPUI.

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
