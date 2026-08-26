# Layout, styling, and presentation

Static design values use Tailwind-compatible classes. Runtime-derived native
geometry uses explicit bounded attributes rather than dynamic CSS expressions.

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

## Motion

Ordinary containers support bounded entrance motion with a stable `id` and a
monotonic request token:

```heex
<div
  id="saved-notice"
  motion_request={assigns.saved_notice_motion}
  motion_duration={180}
  motion_easing="ease_out"
  motion_from_opacity={0.0}
  motion_from_y={8}
>
  ...
</div>
```

The native display interpolates opacity and window-native-pixel x/y offsets to
the ordinary destination presentation. Reusing the token does not restart the
animation. Motion respects GPUI's reduced-motion preference and emits no
completion event; application behavior must not depend on presentation timing.
See [Decision: declarative native motion](declarative-motion.html)
for bounds, ownership, interruption, and remote-display behavior.

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

## Styling

Templates normalize a constrained Tailwind-compatible vocabulary into typed
native style attributes. Static layout and design values should use classes;
reserve `style` for runtime values that cannot be known in the template.

Views import compile-time hexadecimal color sigils for explicit style values:

```elixir
style={[background: ~RGB"0f172a", border_color: ~RGBA"ffffff1a"]}
```

`~RGB` accepts three or six hexadecimal digits; `~RGBA` accepts four or eight.
The sigil name replaces the leading `#`, and short literals expand each digit.
They produce the same `{:rgb, value}` and `{:rgba, value}` values accepted by
the canonical style schema.

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

`<list>` and `<item>` carry no hidden flex, gap, or padding policy; declare
layout explicitly with classes. `<span>` is likewise a neutral container.

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
