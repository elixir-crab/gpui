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

Lowercase tags are renderer primitives such as `div`, `text`, `input`, and
`img`. Native components are always called through `GPUI.UI` or
`GPUI.UI.Overlay`; internal tags such as `<ui_button>` are rejected at template
compile time instead of bypassing their public builder contracts. Duplicate
attributes and unknown tags are also compile errors.

Every native component requires a stable, non-empty string `id`. Component
builders reject unknown options and validate schema-backed attributes and event
names before a snapshot reaches any display, including `GPUI.Test.Display`.
Invalid values raise an `ArgumentError` that names the component, attribute,
expected type or enum, and received value—for example,
`ui_button :disabled must be a boolean; got: "yes"`.

Each builder's ExDoc entry includes a schema-derived option table showing types,
required attributes and events, enum values, and defaults. The corresponding
named option type—for example `t:GPUI.UI.slider_options/0` or
`t:GPUI.UI.Overlay.dialog_options/0`—provides the same contract to editors,
Dialyzer, and library consumers. Both projections come from the shared internal
component schema, so native decoding, validation, types, and documentation
cannot drift into separate option registries.

## Inputs and choices

```elixir
<UI.input
  id="name"
  label="Name"
  value={assigns.name}
  placeholder="Name"
  cleanable={true}
  phx-change="name_changed"
/>

<UI.select
  id="language"
  label="Language"
  value={assigns.language}
  options={[{"Rust", "rust"}, {"Elixir", "elixir"}]}
  phx-change="language_changed"
/>

<UI.combobox
  id="framework"
  label="Framework"
  value={assigns.framework}
  options={assigns.framework_options}
  search_placeholder="Search frameworks"
  phx-change="framework_changed"
  phx-search="framework_searched"
/>
```

Buttons, checkboxes, inputs, selects, and comboboxes require non-empty semantic
labels. Native text-input metadata exposes the controlled value and placeholder;
masked inputs expose a password-input role without leaking their value. Select
metadata exposes the visible label of the controlled option, while searchable
comboboxes retain the upstream expanded-state semantics inside a labeled group.
Input, select, and combobox labels are semantic rather than visible captions.
Use `UI.field/1` when the interface also needs a visual label and controlled help
or error feedback:

```elixir
<UI.field
  label="Display name"
  required={true}
  help="Used in workspace activity."
  error={assigns.errors[:name]}
  class="flex flex-col gap-2"
>
  <UI.input
    id="display-name"
    label="Display name"
    value={assigns.name}
    focus_request={assigns.name_focus_request}
    phx-change="name_changed"
    phx-submit="save"
  />
</UI.field>
```

A field accepts exactly one control. Error feedback replaces help text and stays
owned by the view. Enter emits optional `phx-submit` with the input's current
value. Increment `focus_request` to focus the input after a failed submission;
using a monotonically increasing request avoids repeatedly stealing focus during
ordinary rerenders.

Select, combobox, tabs, and radio-group options accept strings,
`{label, value}` tuples, or `%{label: label, value: value}` maps. Radio maps may
also set `disabled: true`. Option values must be unique.

Editable controlled components require a non-empty `phx-change`. This includes
checkboxes, inputs, selects, comboboxes, switches, radio groups, accordions,
tabs, and sliders. Requiring an owner for native edits prevents a control from
appearing editable while silently snapping back to an unchanged Elixir value.
`phx-search` on comboboxes and `phx-release` on sliders remain optional secondary
events.

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
  label="Plan"
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

Switch and radio-group labels are semantic contracts, not decorative captions:
they provide stable native accessibility names. Switches support Enter and
Space. Radio groups use roving tab stops and Left/Up/Right/Down navigation,
wrapping around disabled options.

## Tabs, accordions, sliders, and splits

Tabs expose a native tab-list with labeled tab roles and controlled selected
state. The selected tab is the single Tab stop; Left/Up and Right/Down move and
select with wrapping, Home/End select endpoints, and Enter/Space activate the
focused tab. Pointer selection focuses the chosen tab. Disabled tab bars expose
disabled semantics and install no pointer, keyboard, Tab, or accessible Click
action. Every activation path emits the same controlled `phx-change` value.

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
  label="Volume"
  value={assigns.volume}
  min={0}
  max={100}
  step={5}
  phx-change="volume_changed"
  phx-release="volume_released"
/>
<UI.split
  id="workspace-split"
  orientation="horizontal"
  sizes={assigns.split_sizes}
  min_sizes={[180, 320]}
  resize_request={assigns.split_resize_request}
  phx-change="workspace_resized"
>
  <div>Navigation</div>
  <div>Content</div>
</UI.split>
```

Tab changes carry one string value. Accordion changes carry an ordered list of
expanded item IDs. A slider label names the accessibility group around the
native slider, which exposes its controlled value, range, step, and orientation.
Slider changes are continuous and `phx-release` fires once
pointer interaction ends. Linear and logarithmic slider scales are supported.

A split has exactly two children and a horizontal or vertical native resize
axis. `sizes`, `min_sizes`, and `max_sizes` are bounded two-element pixel lists.
The display owns pointer drag mechanics and emits the resulting two sizes
through `phx-change`; applications persist those values in assigns. Controlled
sizes are not reapplied during ordinary rerenders, which avoids resetting an
active drag. Increment the monotonic `resize_request` token to programmatically
apply `sizes`. This primitive carries no sidebar, editor, dock, or persistence
policy.

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

### Source-backed data tables

`data_table/1` adds fixed headers, horizontal scrolling, explicit column widths,
numeric alignment, sorting events, and grid accessibility to the uniform
source-backed collection contract. Column definitions precede loaded rows, and
every row contains one child per column:

```elixir
<UI.data_table
  id="processes"
  label="BEAM processes"
  total_count={assigns.total_count}
  offset={assigns.loaded_offset}
  selected={assigns.selected_id}
  selected_index={assigns.selected_index}
  selected_column={assigns.selected_column}
  reveal={assigns.selected_id}
  reveal_index={assigns.selected_index}
  sort_column={assigns.sort_column}
  sort_direction={assigns.sort_direction}
  phx-change="process_selected"
  phx-cell-change="cell_selected"
  phx-sort="process_sorted"
  phx-range="process_range"
  class="h-[480px]"
>
  <UI.table_column id="pid" label="Process" width={140} />
  <UI.table_column id="memory" label="Memory" width={120} align="right" sortable={true} />
  {Enum.map(assigns.loaded_rows, fn row ->
    UI.table_row(%{id: row.id, children: [row.pid, row.memory]})
  end)}
</UI.data_table>
```

Widths are display pixels and each column is bounded from 40 to 2,000 pixels.
Sortable headers emit their stable column ID through `phx-sort`; controlled
`sort_column` and `sort_direction` (`ascending` or `descending`) expose the
current order. Row selection emits the row ID. Cell selection and Left/Right
navigation emit `[row_id, column_id]` through `phx-cell-change`, while Up/Down,
Home/End, Enter, and Space follow the source-backed row rules.

The native accessibility tree uses grid, row, column-header, and grid-cell roles
with one-based row and column indexes and total grid dimensions. Use
`GPUI.Test.table_sort/4`, `GPUI.Test.table_cell_select/5`, and
`GPUI.Test.range/5` for deterministic tests. Full row models remain in the
source process; snapshots contain only column definitions and the loaded row
slice.

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

## Ordinary positioning versus anchored layers

The default positioning model remains HTML-like composition with
Tailwind-compatible classes. Keep content in the ordinary element tree whenever
normal layout and paint order are sufficient:

```elixir
<div class="relative w-full h-full">
  <div class="absolute top-2 right-2">...</div>
</div>
```

Use the neutral `<layer>` primitive only as a native top-layer/portal escape
hatch when content must paint after its ancestors or remain fitted to the native
window. A layer accepts exactly one child and does not own open state,
dismissal, focus, or menu behavior. It is not a replacement for `relative`,
`absolute`, or inset utilities.

```elixir
<layer
  id="completion-popup"
  anchor="bottom_left"
  position_mode="window"
  position_x={assigns.anchor_x}
  position_y={assigns.anchor_y}
  offset_y={6}
  fit="snap_with_margin"
  margin={8}
  priority={10}
>
  <div class="w-[320px] rounded-md bg-slate-800">...</div>
</layer>
```

All static presentation inside the layer—dimensions, spacing, colors, borders,
and typography—still belongs in classes. Runtime-derived native geometry stays
in explicit attributes such as `position_x` and `position_y`.

`position_mode="window"` interprets `position_x` and `position_y` as native
window-relative pixels. `position_mode="local"` interprets them relative to the
layer's normal tree location; omitted coordinates use that location directly.
Anchors identify which corner or edge-center of the child meets the position.
The fit strategy either switches anchors when possible, snaps to the window, or
snaps with a uniform margin. Priority is bounded to `0..1024`; it maps to GPUI's
deferred paint order rather than pretending to be CSS `z-index`. Consequently,
`z-*`, `fixed`, and similar CSS utilities remain unsupported instead of being
mapped to different GPUI behavior. Enum values retain the project's established
underscore convention (`bottom_left`, `snap_with_margin`), while element
composition and static styling remain HTML/Tailwind-like.

## Element bounds

Ordinary containers can opt into asynchronous native bounds events when a
consumer needs to anchor a layer to actual layout rather than guessed
coordinates:

```elixir
<div id="completion-anchor" phx-bounds-change="anchor-bounds-changed">
  ...
</div>
```

The event includes the stable element ID and window-relative native-pixel
geometry:

```elixir
%{
  type: :bounds,
  value: %{
    id: "completion-anchor",
    x: 240.0,
    y: 118.0,
    width: 96.0,
    height: 28.0,
    coordinate_space: "window_native_pixels"
  }
}
```

Observation is opt-in and requires a non-empty `id`. Native events are emitted
only after layout, deduplicated while geometry is unchanged, and updated after
rerender or resize. The event is asynchronous; it does not expose GPUI layout
IDs or provide a synchronous measurement NIF. Use the resulting geometry as
runtime `<layer>` coordinates while keeping static presentation in classes.

## Window lifecycle

Window declarations contain only declarative platform constraints:

```elixir
window "Workspace" do
  size 1100, 720
  min_size 760, 480
  resizable true
  root WorkspaceView
end
```

Views opt into lifecycle handling through an idiomatic optional behaviour
callback rather than arbitrary routing strings:

```elixir
def handle_window_event(:close_request, _event, assigns) do
  {:noreply, %{assigns | close_dialog_open: true}}
end

def handle_window_event(:focus, _event, assigns) do
  {:noreply, %{assigns | window_active: true}}
end

def handle_window_event(:blur, _event, assigns) do
  {:noreply, %{assigns | window_active: false}}
end
```

Exporting `handle_window_event/3` enables interception and activation delivery
for the view's window. A close request remains asynchronous. Return
`{:noreply, assigns}` to keep the window open—for example while rendering an
application-owned confirmation dialog—or `{:close, assigns}` to approve closure.
Ordinary `handle_event/3` handlers may also return `{:close, assigns}` after a
confirmation action.

`min_size` and `resizable` are declarative creation options interpreted by the
native display. The existing `:window_closed` event remains an internal final
notification after a window actually closes. Window `:focus` and `:blur`
callbacks report native activation and are separate from element focus.

## Focus

Focusable primitives use a monotonic request token instead of an
application-controlled focus boolean:

```elixir
<button
  id="search-trigger"
  focus_request={assigns.trigger_focus_request}
  phx-focus="trigger-focused"
  phx-blur="trigger-blurred"
>
  ...
</button>
```

Increment `focus_request` to request native focus once. Rerendering with the
same token does not steal focus again. Native pointer and keyboard focus remain
native state and emit `phx-focus`/`phx-blur` only when focus actually changes.
The event value contains the stable element ID:

```elixir
%{type: :focus, value: %{id: "search-trigger"}}
%{type: :blur, value: %{id: "search-trigger"}}
```

The first generic contract supports `<button>`, low-level `<input>`,
`<UI.input>`, and `<text_surface>`. Focus behavior requires a non-empty stable
`id`; arbitrary focusable containers and controlled `focused={true}` state are
intentionally unsupported.

## Styling

Templates normalize a constrained Tailwind-compatible vocabulary into typed
native style attributes. Static layout and design values should use classes;
reserve `style` for runtime values that cannot be known in the template.
Supported groups include:

- flex display, direction, wrapping, alignment, growth, shrink, the
  `flex-1`, `flex-auto`, `flex-initial`, and `flex-none` shorthands, and basis
  values such as `basis-1/2` or `basis-[240px]`;
- relative and absolute positioning with pixel, percentage, fractional, full, or
  `auto` insets through `inset-*`, `inset-x-*`, `inset-y-*`, `top-*`,
  `right-*`, `bottom-*`, and `left-*`; numeric and arbitrary pixel/percentage
  insets also accept Tailwind's leading-negative form;
- foreground and background colors, including arbitrary six-digit RGB values
  such as `bg-[#101828]`;
- typography, weight, line height, alignment, whitespace, ellipsis/truncation,
  and opacity, including safe arbitrary pixel and numeric values;
- padding, margin, and gaps using Tailwind's numeric spacing convention where
  one unit is four pixels, including decimal values such as `gap-1.5`;
- width, height, and minimum/maximum dimensions using spacing values, arbitrary
  pixels, percentages, or fractions such as `w-1/2`;
- borders, border colors, and radius, including exact arbitrary pixel radii;
- hidden overflow clipping and native cursor feedback.

```elixir
<div class="relative flex flex-1 basis-1/2 min-h-0 gap-1.5 p-4 overflow-hidden bg-[#101828]">
  <text class="absolute top-2 right-2 text-[#94a3b8] text-xs">Draft</text>
  <text class="truncate text-[#f8fafc] text-[13px] leading-[18px] font-semibold">
    Settings
  </text>
</div>
```

Use the semantic `<scroll>` element for scrolling. An overflow utility is not
accepted as a substitute because GPUI scrolling requires native scroll state and
behavior. Unsupported variants and CSS expressions, such as `hover:*`,
`mx-auto`, or `w-[calc(...)]`, remain in the serialized `class` attribute
instead of being silently reinterpreted. Programmatic trees can use helpers such
as `GPUI.style/3`, `GPUI.px/1`, and `GPUI.rgb/1`.

## Themes

The component theme belongs to the process-global native display environment and
refreshes every open native window:

```elixir
{:ok, display} = GPUI.Display.Native.start_link(theme: :dark)
:ok = GPUI.Display.Native.set_theme(display, :light)
```

See `GPUI.UI` for the complete option-level API and
[Overlays and menus](overlays-and-menus.html) for named-slot components.
