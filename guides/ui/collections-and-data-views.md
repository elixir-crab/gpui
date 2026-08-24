# Collections and data views

GPUI provides variable-height and uniform source-backed collection primitives.
Stable identities and explicit bounds let native displays virtualize layout
without moving application data policy out of Elixir.

## Virtualized collections

`virtual_collection/1` is the variable-height primitive for transcripts,
activity feeds, and other heterogeneous collections. The complete logical
collection stays in the renderer-independent snapshot, while the native display
measures and renders the visible region with bounded pixel `overdraw`.

```elixir
<UI.virtual_collection
  id="transcript"
  label="Conversation"
  alignment="bottom"
  follow="tail"
  follow_request={assigns.follow_request}
  overdraw={320}
  phx-range="messages_visible"
  class="h-[560px]"
>
  {Enum.map(assigns.messages, fn message ->
    UI.virtual_item(%{
      id: message.id,
      revision: message.revision,
      children: [render_message(message)]
    })
  end)}
</UI.virtual_collection>
```

`alignment="bottom"` starts short collections at the lower edge. `follow="tail"`
tracks appended or growing tail content until the user scrolls away; increment
`follow_request` to explicitly return to the tail. To reveal a retained item,
set `reveal` and increment `reveal_request`. The truthful placement strategies
for the variable-height primitive are `nearest` and `top`.

Every item ID is stable, unique, non-empty, and at most 128 bytes. Increment an
item's `revision` when retained content may change measured height. Appends,
prepends, removals, and revision changes preserve GPUI's measured-height cache
for unaffected IDs. Collections are bounded to 100,000 items and `overdraw` to
4,096 pixels.

`phx-range` emits deduplicated visible `%{first: first, last: last}` ranges with
an exclusive
`last`. Unlike the uniform source-backed primitive below, variable collections
currently require all logical item nodes in each snapshot: unknown offscreen
heights have no truthful placeholder geometry. Remote displays receive this
same complete serializable contract.

`virtual_list/1` presents source-backed uniform collections through GPUI's native uniform-list
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

Use `GPUI.Test.change/4`, `GPUI.Test.select/4`, and `GPUI.Test.range/5` for
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
