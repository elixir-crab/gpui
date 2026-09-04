# Presentation primitives

Presentation primitives add bounded native decoration without moving application
state, topology, parsing, or accessibility policy out of Elixir. They are
ordinary schema-owned `GPUI.UI` components and serialize through the same local,
test, and remote snapshot path as other elements.

Use these primitives for neutral presentation mechanics:

- `edge_fade/1` decorates the edges around arbitrary child content;
- `frost/1` renders a surface with an explicit solid or translucent fallback;
- `paint/1` renders a bounded rectangle-and-line display list.

They are not native callbacks, shader APIs, plugins, or arbitrary component
injection. See [Presentation extension contracts](presentation-contracts.html)
for renderer versions, capability advertisement, and generated decoding.

## Edge fades

An edge fade wraps arbitrary children. It does not own scrolling, clipping,
collection state, or content topology, so place the semantic `<scroll>` element
inside it when the content should scroll:

```elixir
<UI.edge_fade
  id="activity-fades"
  edges={[:top, :bottom]}
  size={24}
  opacity={0.9}
  class="relative grow min-h-0 rounded-lg bg-slate-900"
>
  <scroll class="w-full h-full p-5">
    <text>Activity content</text>
  </scroll>
</UI.edge_fade>
```

`edges` is a unique subset of `:top`, `:right`, `:bottom`, and `:left`. `size`
is bounded to `1..256` native pixels and `opacity` to `0.0..1.0`. Static
container presentation still belongs in Tailwind-compatible classes.

When a display does not implement the optional fade enhancement, the child tree
continues to render normally.

## Frost surfaces

A frost surface requires an explicit fallback policy:

```elixir
<UI.frost
  id="summary-frost"
  fallback="translucent"
  opacity={0.86}
  reduced_transparency={assigns.reduced_transparency}
  class="p-4 rounded-lg border border-slate-700"
>
  <text class="font-semibold">Summary</text>
</UI.frost>
```

`fallback` is either `"solid"` or `"translucent"`, and `opacity` is bounded to
`0.0..1.0`. The pinned native stack has no element-level backdrop-blur API, so
`frost/1` does not claim one.

Accessibility policy remains application-owned. Set `reduced_transparency` from
the serialized application policy; when true, it forces an opaque surface even
if the ordinary fallback is translucent. A native display must not infer or
replace that policy by changing snapshot topology.

## Bounded custom paint

`paint/1` renders a serializable display list in the bounds established by its
classes:

```elixir
<UI.paint
  id="sparkline"
  commands={[
    %{type: :rect, x: 0, y: 30, width: 220, height: 1, color: 0x334155FF},
    %{type: :line, x1: 8, y1: 28, x2: 210, y2: 6, width: 2, color: 0x38BDF8FF}
  ]}
  class="w-full h-12"
/>
```

Version 1 accepts only closed `:rect` and `:line` command maps:

```elixir
%{type: :rect, x: x, y: y, width: width, height: height, color: rgba}
%{type: :line, x1: x1, y1: y1, x2: x2, y2: y2, width: width, color: rgba}
```

Colors are 32-bit RGBA integers. The list is limited to 256 commands;
coordinates and dimensions are bounded, rectangle dimensions may be zero, and
line widths must be greater than zero. Unknown commands, shader source,
callbacks, and opaque payloads are rejected before a snapshot reaches a
display.

The canvas fills its styled wrapper. Declare its width and height through
classes or other ordinary bounded layout; paint commands do not establish the
component's layout size. A display without paint support renders an empty canvas
rather than executing an alternative payload.

## Fallbacks and remote displays

Presentation support is informational and display-local. It never determines
whether a snapshot may mount and never permits a display to add, remove, or
rearrange application elements. Fallbacks travel in the serialized component,
so local and remote displays receive the same topology and application policy.

Use `GPUI.Display.Support.presentation_capabilities/2` only for diagnostics or display
introspection. Do not branch application topology on it.

## Example and testing

The complete composition example is
`examples/features/presentation_primitives.exs`. Renderer-independent tests can
query these components as ordinary elements:

```elixir
runtime = start_runtime!(Features.PresentationPrimitives.App)

assert %{type: :ui_frost} = runtime |> tree() |> find!(id: "summary-frost")
assert %{type: :ui_edge_fade} = runtime |> tree() |> find!(id: "activity-fades")
assert %{type: :ui_paint} = runtime |> tree() |> find!(id: "sparkline")
```

Use deterministic native tests for decoder rejection, actual GPUI layout, and
native presentation mechanics. Pixel-level readability and appearance remain
visual-evidence claims rather than renderer-independent assertions.
