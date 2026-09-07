# Forms and controls

Controlled components emit requested changes while Elixir remains authoritative
over persisted values. Native displays retain transient focus, selection,
pointer, and drag state across ordinary rerenders.

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

## Progress

`progress/1` renders a native accessible progress indicator. Values are
controlled and must remain between zero and `max`; set `indeterminate={true}`
when the amount of completed work is unknown.

```elixir
<UI.progress id="import" label="Importing image" value={assigns.progress} max={100} />
```

## Button variants and sizes

Button variants are `default`, `primary`, `secondary`, `danger`, `warning`,
`success`, `info`, `ghost`, `link`, and `text`. Component sizes are `xs`, `sm`,
`md`, and `lg` where supported.

## Focus

The semantic `<button>` primitive is a styled native button region with built-in
button accessibility role, Tab focus, Enter/Space activation, and unified
pointer/AccessKit activation. Use `<UI.button>` when GPUI Component variants,
sizing, loading, selection, or clipboard capabilities are needed.

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

The first generic contract supports `<button>`, low-level `<text_input>`,
`<UI.input>`, and `<text_surface>`. Focus behavior requires a non-empty stable
`id`; arbitrary focusable containers and controlled `focused={true}` state are
intentionally unsupported.

Use `<text_input>` only for an unlabelled low-level single-line primitive.
Ordinary forms should prefer `<UI.input>`; revisioned editor and composer
surfaces should use `<text_surface>`.
