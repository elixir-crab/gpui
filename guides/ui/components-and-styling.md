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

## Button variants and sizes

Button variants are `default`, `primary`, `secondary`, `danger`, `warning`,
`success`, `info`, `ghost`, `link`, and `text`. Component sizes are `xs`, `sm`,
`md`, and `lg` where supported.

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
