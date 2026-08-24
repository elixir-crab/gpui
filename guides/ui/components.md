# UI components

`GPUI.UI` provides controlled Elixir components backed directly by
`gpui-component`. Components build ordinary `%GPUI.Element{}` data; the native
display owns GPUI entities, callbacks, focus, and transient interaction state.

Choose a guide by the task you are working on:

- [Templates and elements](templates-and-elements.html) explains HEEx-style
  templates, primitive tags, component aliases, stable identities, and
  schema-backed validation.
- [Forms and controls](forms-and-controls.html) covers inputs, choices, grouped
  controls, tabs, accordions, sliders, splits, progress, and focus.
- [Collections and data views](collections-and-data-views.html) covers variable
  and uniform virtualization, source-backed lists, tables, trees, and code
  viewers.
- [Text and editing](text-and-editing.html) covers selectable rich text.
- [Editable text surfaces](editable-text.html) covers persistent buffers,
  revisioned transactions, submission, geometry, and text annotations.
- [Layout, styling, and presentation](layout-styling-and-presentation.html)
  covers Tailwind-compatible classes, layers, motion, bounds, and themes.
- [Presentation primitives](presentation-primitives.html) covers bounded edge
  fades, frost fallbacks, and rectangle-and-line custom paint.
- [Resources and display actions](resources-and-display-actions.html) covers
  display-local file selection, clipboard writes, image decoding, and raster
  resources.
- [Windows and lifecycle](windows-and-lifecycle.html) covers declarative window
  constraints and lifecycle callbacks.
- [Commands and keyboard shortcuts](commands-and-shortcuts.html) and
  [Overlays and menus](overlays-and-menus.html) document those focused
  interaction systems.

Every native component requires a stable, non-empty string `id`. Controlled
values remain application-owned; displays retain only transient interaction
state and emit events requesting authoritative Elixir updates.
