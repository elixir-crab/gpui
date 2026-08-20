# Declarative native motion boundaries

GPUI motion is a bounded presentation request on ordinary declarative
containers. Elixir owns when motion starts and the final tree; the display owns
transient interpolation and frame scheduling.

## Contract

A motion request requires a stable element `id` and a monotonically increasing
`motion_request` token:

```heex
<div
  id="notice"
  motion_request={assigns.notice_motion}
  motion_duration={180}
  motion_easing="ease_out"
  motion_from_opacity={0.0}
  motion_from_x={0.0}
  motion_from_y={8.0}
>
  ...
</div>
```

A new token starts an entrance transition from the declared opacity and pixel
offsets to the ordinary, fully opaque zero-offset presentation. Re-rendering
with the same token preserves native animation state rather than restarting it.
The first contract intentionally does not animate layout dimensions, text
shaping, colors, scroll position, window geometry, or arbitrary style values.

Supported bounds are:

```text
request token       non-negative integer
duration            1–10,000 ms
delay                0–10,000 ms
opacity              0.0–1.0
x/y offset           -4,096–4,096 native pixels
easing               linear | ease_in | ease_out | ease_in_out
policy               respect_system | disabled
```

`respect_system` is the default and uses GPUI's application-level reduced-motion
preference. GPUI immediately renders the destination state and schedules no
animation frames when reduced motion is active. `disabled` also renders the
destination without wrapping the element in animation state. An `always` mode
is intentionally absent because pinned GPUI animation wrappers always honor the
system reduced-motion setting.

## Ownership and interruption

The snapshot carries only the request and bounded declaration. Native state
owns the start time, easing progress, delay phase, and frame requests. Changing
the token replaces the animation identity and starts the new declaration.
Removing the element drops its transient state. No completion event is emitted:
application correctness must not depend on display timing, and remote displays
may observe different frame schedules.

Motion does not alter hit-testing policy, accessibility identity, controlled
values, or the authoritative snapshot. Static layout and destination styling
remain ordinary classes and styles.
