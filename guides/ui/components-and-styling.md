# Components and styling

`GPUI.UI` provides controlled Elixir components backed directly by
`gpui-component`. Components build ordinary `%GPUI.Element{}` data; the native
display owns GPUI entities, callbacks, focus, and transient interaction state.

## Aliases and templates

Component aliases are resolved from the calling module:

```elixir
alias GPUI.UI

~GPUI"""
<div class="flex flex-col gap-4 p-4">
  <UI.button id="save" label="Save" variant="primary" phx-click="save" />
  <UI.checkbox
    id="remember"
    label="Remember me"
    checked={assigns.remember}
    phx-change="remember_changed"
  />
</div>
"""
```

Every stateful component requires a stable, non-empty string `id`.

## Inputs and choices

```elixir
<UI.input
  id="name"
  value={assigns.name}
  placeholder="Name"
  cleanable={true}
  phx-change="name_changed"
/>

<UI.select
  id="language"
  value={assigns.language}
  options={[{"Rust", "rust"}, {"Elixir", "elixir"}]}
  phx-change="language_changed"
/>

<UI.combobox
  id="framework"
  value={assigns.framework}
  options={assigns.framework_options}
  search_placeholder="Search frameworks"
  phx-change="framework_changed"
  phx-search="framework_searched"
/>
```

Select, combobox, tabs, and radio-group options accept strings,
`{label, value}` tuples, or `%{label: label, value: value}` maps. Radio maps may
also set `disabled: true`. Option values must be unique.

Inputs preserve native focus, cursor, selection, clipboard, and IME state while
controlled snapshots are reconciled. Combobox search and option replacement can
be asynchronous.

## Boolean and grouped controls

```elixir
<UI.switch
  id="notifications"
  label="Notifications"
  checked={assigns.notifications}
  loading={assigns.loading}
  phx-change="notifications_changed"
/>

<UI.radio_group
  id="plan"
  value={assigns.plan}
  options={[
    {"Free", "free"},
    %{label: "Pro", value: "pro", disabled: true},
    {"Team", "team"}
  ]}
  orientation="horizontal"
  phx-change="plan_changed"
/>
```

Switches support Enter and Space. Radio groups use roving tab stops and
Left/Up/Right/Down navigation, wrapping around disabled options.

## Tabs, accordions, and sliders

```elixir
<UI.tabs
  id="section"
  value={assigns.section}
  options={[{"General", "general"}, {"Advanced", "advanced"}]}
  variant="underline"
  phx-change="section_changed"
/>

<UI.accordion
  id="details"
  expanded={assigns.expanded}
  multiple={true}
  phx-change="details_changed"
>
  <UI.accordion_item id="account" title="Account">
    <text>Account details</text>
  </UI.accordion_item>
</UI.accordion>

<UI.slider
  id="volume"
  value={assigns.volume}
  min={0}
  max={100}
  step={5}
  phx-change="volume_changed"
  phx-release="volume_released"
/>
```

Tab changes carry one string value. Accordion changes carry an ordered list of
expanded item IDs. Slider changes are continuous and `phx-release` fires once
pointer interaction ends. Linear and logarithmic slider scales are supported.

## Progress and display-side actions

`progress/1` renders a native accessible progress indicator. Values are
controlled and must remain between zero and `max`; set `indeterminate={true}`
when the amount of completed work is unknown.

```elixir
<UI.progress id="import" label="Importing image" value={assigns.progress} max={100} />
```

`file_picker/1` opens the platform picker on the machine running the display.
It reads one selected file with a bounded size and emits bytes rather than a
filesystem path, so the same event remains meaningful for remote displays.
`max_bytes` defaults to 25 MiB and cannot exceed 100 MiB.

```elixir
<UI.file_picker
  id="source-image"
  label="Choose image"
  prompt="Choose an image"
  max_bytes={25 * 1_024 * 1_024}
  phx-change="image_selected"
/>
```

The event value is one of:

```elixir
%{operation_id: 42, status: :selected, name: "photo.png", size: 12_345, data: encoded_bytes}
%{operation_id: 42, status: :cancelled}
%{operation_id: 42, status: :error, reason: "..."}
```

`copy_button/1` writes its controlled `text` to the clipboard owned by the
local display and emits `phx-click` after the platform write is requested. This
also gives remote applications the expected user-side clipboard rather than the
application server's clipboard.

```elixir
<UI.copy_button
  id="copy-css"
  label="Copy CSS"
  text={assigns.css}
  phx-click="css_copied"
/>
```

Tests select or cancel files deterministically with `GPUI.Test.file_select/5`
and `GPUI.Test.file_cancel/3`; neither helper opens a native window.

## Virtualized collections

`virtual_list/1` presents large collections through GPUI's native uniform-list
layout. Every row has a stable ID and the same declared height; only the visible
range is constructed and laid out natively.

```elixir
<UI.virtual_list
  id="processes"
  label="BEAM processes"
  selected={assigns.selected_pid}
  reveal={assigns.selected_pid}
  reveal_strategy="nearest"
  item_height={48}
  phx-change="process_selected"
  class="h-[480px]"
>
  {Enum.map(assigns.processes, fn process ->
    UI.virtual_list_item(%{
      id: process.pid,
      children: [process.label]
    })
  end)}
</UI.virtual_list>
```

`selected` is controlled and changes emit the selected item ID. `reveal`
requests programmatic scrolling with `nearest`, `top`, `center`, or `bottom`
placement. Up/Down, Home/End, Enter, and Space operate from one listbox tab stop
and skip disabled rows. Pointer selection focuses the list, and native
accessibility exposes listbox and option roles with an active descendant.

The list itself must have a fixed or maximum height. Rows that differ from
`item_height` violate the uniform-list contract. Filtering and sorting may
replace or reorder children while scroll state remains attached to the list's
stable ID.

### Source-backed lists

Rendering is not the only cost of a large collection: putting every child—or
the full source model—into view assigns also serializes it into every local or
remote snapshot. Source-backed lists keep the full model in a supervised source
process and put only the current loaded slice in assigns.

```elixir
<UI.virtual_list
  id="records"
  label="Records"
  total_count={assigns.total_count}
  offset={assigns.loaded_offset}
  overscan={8}
  selected={assigns.selected_id}
  selected_index={assigns.selected_index}
  reveal={assigns.selected_id}
  reveal_index={assigns.selected_index}
  item_height={40}
  phx-change="record_selected"
  phx-range="records_range"
  class="h-[480px]"
>
  {Enum.map(assigns.loaded_rows, &row/1)}
</UI.virtual_list>
```

`phx-range` emits `%{first: first, last: last}` with an exclusive `last` index.
The requested range already includes `overscan`. The source responds by loading
a contiguous slice, setting `offset` to `first`, and replacing `loaded_rows`.
`selected_index` and `reveal_index` preserve controlled selection and distant
reveal while the selected row is unloaded. Placeholder rows retain the correct
scroll geometry until the requested slice arrives. Arrow navigation uses the
loaded overscan; Home and End activate only when the corresponding endpoint is
loaded. Applications can perform global jumps by changing the controlled
selection and reveal index.

Use `GPUI.Test.range/5` to request ranges without a native display. Native range
events are coalesced per render cycle and use the same protocol over remote
displays.

### Accessible trees

`tree/1` and `tree_item/1` apply the same uniform-height, source-backed range,
selection, and reveal contracts to hierarchical collections. The source emits a
flattened visible slice; each item declares its hierarchy and accessibility
metadata:

```elixir
<UI.tree
  id="files"
  label="Repository files"
  total_count={assigns.total_count}
  offset={assigns.loaded_offset}
  selected={assigns.selected_id}
  selected_index={assigns.selected_index}
  reveal={assigns.selected_id}
  reveal_index={assigns.selected_index}
  phx-change="file_selected"
  phx-toggle="directory_toggled"
  phx-range="file_range"
  class="h-[480px]"
>
  {Enum.map(assigns.loaded_entries, fn entry ->
    UI.tree_item(%{
      id: entry.id,
      parent_id: entry.parent_id,
      level: entry.level,
      branch: entry.branch?,
      expanded: entry.expanded?,
      position: entry.position,
      set_size: entry.set_size,
      children: [entry.label]
    })
  end)}
</UI.tree>
```

`phx-change` emits the selected item ID. `phx-toggle` requests controlled branch
expansion or collapse; the application updates its source model and visible
slice. Left collapses an expanded branch or selects its loaded parent. Right
expands a collapsed branch or selects its first loaded, enabled child. Up and
Down skip disabled items, while Home and End retain the source-backed endpoint
rules. Native accessibility exposes tree and tree-item roles plus level,
expanded, selected, position-in-set, and set-size metadata.

Use `GPUI.Test.tree_toggle/4`, `GPUI.Test.select/4`, and `GPUI.Test.range/5` for
deterministic tree tests. All three event paths are forwarded unchanged by
remote displays.

### Source-backed code and diff viewers

`code_viewer/1` specializes the uniform source-backed collection contract for
monospaced source text and unified diffs. Lines do not wrap. `max_columns`
provides stable horizontal geometry even when the longest line is not in the
loaded slice, while `tab_width` controls deterministic tab expansion.

```elixir
<UI.code_viewer
  id="preview"
  label="File preview"
  mode="diff"
  total_count={assigns.total_count}
  offset={assigns.loaded_offset}
  selected={assigns.selected_id}
  selected_index={assigns.selected_index}
  reveal={assigns.selected_id}
  reveal_index={assigns.selected_index}
  max_columns={assigns.max_columns}
  tab_width={4}
  phx-change="line_selected"
  phx-range="preview_range"
  phx-copy="line_copied"
  class="h-[480px]"
>
  {Enum.map(assigns.loaded_lines, fn line ->
    UI.code_line(%{
      id: line.id,
      number: line.number,
      text: line.text,
      kind: line.kind
    })
  end)}
</UI.code_viewer>
```

Modes are `plain` and `diff`. Diff line kinds are `addition`, `deletion`,
`context`, and `hunk`; plain viewers can additionally use `debug`, `info`,
`warning`, and `error` for theme-aware semantic log presentation. Line numbers
are optional. Up/Down, Page Up/Page Down,
Home/End, Enter, and Space use one accessible listbox tab stop and preserve the
source-backed endpoint rules. Pointer selection emits the stable line ID.

Ctrl/Cmd+C writes the selected loaded line to the clipboard on the display
machine. This is intentionally display-local for remote sessions. If
`phx-copy` is set, the viewer emits an acknowledgement after requesting the
platform write. Tests use `GPUI.Test.select/4`, `GPUI.Test.range/5`, and
`GPUI.Test.copy_selected_line/3`; deterministic helpers do not access the host
clipboard.

## Button variants and sizes

Button variants are `default`, `primary`, `secondary`, `danger`, `warning`,
`success`, `info`, `ghost`, `link`, and `text`. Component sizes are `xs`, `sm`,
`md`, and `lg` where supported.

## Images and raster resources

`GPUI.Image.decode/1` converts common encoded image bytes into a validated
`GPUI.Raster`. Decoding runs on a dirty CPU scheduler; applications should keep
file access and larger workflows in supervised tasks.

```elixir
with {:ok, bytes} <- File.read(path),
     {:ok, raster} <- GPUI.Image.decode(bytes) do
  GPUI.Runtime.put_resource(runtime, "preview", GPUI.Raster.to_payload(raster))
end
```

Render an inline raster with `<img raster={raster} label="Preview" />`; `label`
provides its native accessibility name. For images that survive
multiple view updates, install the raster once and render
`GPUI.ResourceRef.new("preview", :raster)` instead. Resource references avoid
copying the full pixel payload through each later snapshot and work across local
and remote displays.

## Styling

Templates normalize a constrained Tailwind-compatible vocabulary into typed
native style attributes. Supported groups include:

- flex display, direction, wrapping, alignment, growth, and shrink;
- foreground and background colors;
- typography, weight, and opacity;
- padding, margin, and gaps;
- width, height, and minimum/maximum dimensions;
- borders, border colors, and radius.

```elixir
<div class="flex flex-col w-[420px] min-h-[240px] gap-4 p-4 bg-slate-900">
  <text class="text-white text-xl font-semibold">Settings</text>
</div>
```

Unsupported classes remain in the serialized `class` attribute instead of being
silently reinterpreted. Programmatic trees can use helpers such as `GPUI.style/3`,
`GPUI.px/1`, and `GPUI.rgb/1`.

## Themes

The component theme belongs to the process-global native display environment and
refreshes every open native window:

```elixir
{:ok, display} = GPUI.Display.Native.start_link(theme: :dark)
:ok = GPUI.Display.Native.set_theme(display, :light)
```

See `GPUI.UI` for the complete option-level API and
[Overlays and menus](overlays-and-menus.html) for named-slot components.
