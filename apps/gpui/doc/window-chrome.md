# Decision: declarative native window chrome

GPUI exposes two renderer-independent window chrome modes:

```elixir
window "Application" do
  chrome(:system)
  root(MyView)
end

window "Application" do
  chrome(:content)
  root(MyView)
end
```

`:system` is the default. The platform owns the title bar and its ordinary
controls. `:content` extends application content into the title-bar region and
lets the application compose its visible chrome from ordinary elements.

## Neutral control regions

Application-rendered chrome uses `window_control` on ordinary containers:

```heex
<div class="flex h-10 items-center" window_control="drag">
  <text>Application</text>
  <div class="flex grow" />
  <button window_control="minimize"><text>–</text></button>
  <button window_control="maximize"><text>□</text></button>
  <button window_control="close"><text>×</text></button>
</div>
```

The closed vocabulary is:

- `drag`
- `minimize`
- `maximize`
- `close`

These are native window-control regions, not ordinary application events.
Visible labels, icons, spacing, hover presentation, and control arrangement
remain application-owned. Consumers must not assume identical control geometry
or placement across platforms.

## Platform interpretation

- **macOS:** content chrome uses a transparent full-size title bar and retains
  the system traffic lights. Drag regions ask AppKit to perform the current
  window drag. Application-rendered minimize/maximize/close controls are
  supported but usually unnecessary when traffic lights remain visible.
- **Windows:** content chrome removes the standard caption presentation.
  Control regions use native non-client hit testing, preserving Snap Layouts
  and ordinary caption-button behavior.
- **Linux:** content chrome requests client-side decorations. Wayland
  compositors may refuse the request; X11 may fall back to server decorations
  when no compositor supports client decoration. When client decoration is
  active, the application must render usable controls.

Chrome does not promise pixel-identical windows or identical system-control
placement.

## Snapshot authority and reconciliation

Chrome is a `GPUI.WindowSpec` fact and is serialized in ordinary snapshots,
including remote snapshots. It is not an imperative remote-window RPC.

Chrome is a creation-time platform option in the pinned GPUI APIs. If a
snapshot changes a window's chrome or another creation-time window option, the
local display closes and reopens that native window while retaining the same
session window ID. Native focus, position, and other transient platform state
may therefore reset. Applications should normally keep chrome stable for a
window's lifetime.

The window title remains an accessibility and task-switcher fact even when the
visible title is application-rendered.

## Close policy

A content-chrome close control enters the same asynchronous close-request path
as ordinary system chrome. It never blocks the GPUI loop waiting for the BEAM.
Views with `handle_window_event/3` may keep the window open with
`{:noreply, assigns}` or approve closure with `{:close, assigns}`.

## Deliberately deferred

The first contract does not expose:

- macOS traffic-light coordinates;
- arbitrary platform button layouts;
- custom window-menu policy;
- Mica, blur, or transparent window backgrounds;
- controlled minimized, maximized, or fullscreen state;
- window geometry commands;
- platform-specific title-bar APIs.

Those require separate bounded contracts and platform evidence.
