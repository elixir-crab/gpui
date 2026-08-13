# Native accessibility boundaries

GPUI snapshots are renderer-independent, but programmatic accessibility only
becomes real when a display maps snapshot semantics into its platform
accessibility tree and handles assistive-technology actions. This guide records
the boundary for the pinned native stack:

```text
GPUI:           1a246efd7e1b83ab568ec5e3e6c1a43a42e1abba
gpui-component: 5c5eb1db04dc1146bdec903a8ac74407bd6c2098
```

It is an implementation boundary, not a promise of web ARIA parity.

## What the native stack provides

The pinned GPUI integrates with AccessKit. A GPUI element contributes a node
only when it has both a stable element ID and an AccessKit role. GPUI currently
exposes native builders for:

- role, label, description, and announced keyboard shortcuts;
- selected, expanded, and tri-state toggled state;
- string, placeholder, numeric, minimum, maximum, and step values;
- orientation, heading level, position/size in set, and table coordinates;
- active-descendant focus for composite widgets;
- synthetic accessibility children for custom text-like elements;
- assistive-technology actions, with click handlers automatically accepting the
  accessible click action.

GPUI sends AccessKit trees and actions through platform adapters on:

- macOS via `accesskit_macos`;
- Windows via `accesskit_windows`;
- Linux X11 and Wayland via `accesskit_unix` (the platform bridge used for
  AT-SPI environments).

This means bounded semantic metadata can truthfully reach native assistive
technology on all three target families. Actual behavior still depends on the
platform adapter, desktop accessibility services, and the completeness of each
component's role, identity, state, and action wiring.

## What gpui_ex already maps

The native renderer already emits accessibility nodes for several semantic
components:

- images: image role and label;
- buttons: component-owned button/link role and label behavior;
- inputs: input-specific roles, labels, values, and placeholders; password
  values are not exposed;
- select and combobox: roles, labels, selected visible values, and placeholders;
- switch and radio group: controlled state, labels, and orientation;
- slider and progress/display values: numeric value bounds and orientation;
- popover, dropdown, and dialog triggers: label and expanded state;
- tree, virtual list, code viewer, and data table: collection roles, selected or
  expanded state, active descendants, set positions, and table coordinates.

These mappings are component policy. Applications should not need to recreate
native roles for ordinary semantic controls.

## Renderer-independent contract direction

Accessibility facts added to the public schema must remain bounded,
serializable, and useful to every display. The first neutral vocabulary should
be limited to facts directly supported by GPUI/AccessKit:

```text
accessibility_role
accessibility_label
accessibility_description
accessibility_value
accessibility_selected
accessibility_expanded
accessibility_checked
accessibility_orientation
```

Numeric value metadata, heading/set/table coordinates, active descendants, and
synthetic text children should be added only with a concrete component need and
behavioral tests. Native semantic elements keep their implicit roles; explicit
role overrides are primarily for custom generic elements and must use a closed
role vocabulary.

Accessibility metadata belongs in the element snapshot. Therefore test and
remote displays can inspect and transport the same facts even though only a
native display publishes an operating-system accessibility tree.

## Validation rules

A future schema must reject misleading combinations instead of silently
approximating them. At minimum:

- a node with an explicit role must also have a stable renderer identity;
- `checked` is restricted to check box, radio, switch, and equivalent toggle
  roles;
- `selected` is restricted to selectable collection items and tabs;
- `expanded` is restricted to disclosures and expandable composite items;
- orientation is restricted to roles such as slider, splitter, radio group,
  tab list, and applicable collections;
- masked input values must never be serialized as accessible values;
- disabled, read-only, modal, focus restoration, and hidden/decorative behavior
  must not be claimed until the pinned GPUI API and component action paths can
  represent them truthfully.

Unknown roles and unsupported state combinations should fail schema validation
while preserving their source spelling in diagnostics.

## Identity is part of accessibility

A role alone is insufficient. GPUI derives AccessKit node identity from the
hierarchy of element IDs. IDs must be unique within a frame and stable across
frames; otherwise assistive technology observes removal and insertion rather
than a meaningful update. Collection renderers must not derive repeated text
nodes from one source location without a stable per-item ancestor or explicit
ID.

The public accessibility contract must reuse the framework's renderer identity
rather than introduce a second application-visible accessibility ID namespace.

## Keyboard and focus are separate obligations

An accessibility tree does not make a component operable. Each semantic
component also needs coherent:

- Tab and Shift-Tab traversal;
- Enter/Space or arrow-key activation where appropriate;
- disabled-state exclusion from focus and actions;
- composite active-descendant behavior;
- modal focus containment and restoration;
- monotonic focus requests for imperative restoration.

Accessible actions must invoke the same consumer-owned event path as pointer or
keyboard activation. They must not mutate application assigns independently in
Rust.

## Explicitly unsupported claims

Until separately implemented and validated, gpui_ex must not claim:

- arbitrary ARIA attribute compatibility;
- browser accessibility-tree or DOM behavior;
- live regions, relationships such as `labelledby`/`describedby`, or arbitrary
  ownership graphs;
- portable disabled, read-only, modal, hidden, or invalid state solely because
  similarly named HTML attributes exist;
- complete screen-reader parity among VoiceOver, Narrator, and Linux AT-SPI;
- accessibility for visual-only overlays that lack stable IDs, roles, actions,
  and coherent focus behavior.

## Recommended implementation order

1. Add a generated, closed accessibility vocabulary to renderer-independent
   element attributes.
2. Map label and description plus a small role set for generic elements.
3. Preserve semantic component defaults and reject conflicting overrides.
4. Add selected, expanded, checked, value, and orientation only alongside
   role/state validation.
5. Add snapshot and remote round-trip tests.
6. Add native AccessKit-tree or platform inspection tests where the adapter
   offers a deterministic harness.
7. Audit keyboard and assistive-action equivalence for buttons, choices,
   inputs, sliders, dialogs, tabs, trees, and split handles.

Visual screenshots are not accessibility evidence. Native accessibility claims
require inspecting the platform/AccessKit tree or driving an accessible action.
