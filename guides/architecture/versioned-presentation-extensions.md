# Versioned presentation extension contracts

GPUI presentation extensions are schema-owned optional renderer capabilities.
They are not plugins, dynamically loaded native modules, arbitrary component
injection, callbacks, or opaque payloads.

## Architectural position

An extension augments an existing `GPUI.Schema.Component` while preserving the
normal renderer-independent path:

```text
GPUI.Schema.Component
→ GPUI.Element payload
→ GPUI.Snapshot
→ GPUI.Display
→ RustQ-generated decoder and dispatch
→ handwritten GPUI renderer
```

Application topology and fallback policy remain in Elixir. Displays may enhance
presentation, but capability support never changes snapshot topology or blocks a
mount.

## Exact versions

Each extension contract declares a stable atom ID, a positive integer version,
and a closed capability vocabulary. The current built-ins are:

```text
edge_fade@1  linear_gradient, theme_background
frost@1      solid_fallback, translucent_fallback,
             reduced_transparency, backdrop_blur
paint@1      rect, line
```

New snapshots carry `__extension_version__` in the renderer-hidden `attrs` map.
Applications cannot set the field through public builders. Native generated
decoders require the exact declared version before decoding the component.

During the pre-stable compatibility window, a missing version is interpreted as
version 1. An explicit malformed or mismatched version is rejected. Stable
protocol revisions should require the field and remove this legacy allowance.

An incompatible field or command change increments the contract version. A new
capability must not silently broaden an existing closed version when it changes
the wire schema. Implementations may retain multiple exact versions when old
snapshots must remain supported.

## Capabilities and fallbacks

A contract's capability list is vocabulary, not an implementation claim.
`GPUI.Display.presentation_capabilities/2` reports only behavior that the
particular display implements. For example, frost version 1 declares
`backdrop_blur`, but native displays do not advertise it until a real and tested
platform implementation exists.

Every optional enhancement requires a deterministic fallback in the serialized
component declaration:

- edge fade falls back to ordinary child rendering;
- frost follows its solid/translucent and reduced-transparency policy;
- paint falls back to an empty bounded canvas when unsupported.

Accessibility policy is serialized by Elixir and overrides native enhancement.
In particular, reduced transparency must disable translucent or blur effects.

## Remote advertisement

Remote hello messages may include a bounded informational `presentation` list.
Entries use exact contract versions and capabilities validated against
`GPUI.Schema`. Missing presentation support is equivalent to an empty list and
is never a handshake requirement.

Transport capabilities such as `display_v1` and `window_topology_v1` remain
separate because they govern whether operations can be exchanged safely.
Presentation support is diagnostic and display-local.

## Evolution restrictions

Extensions may use bounded scalar fields, closed enums, bounded collections, and
existing typed resource references. They may not contain functions, modules,
PIDs, ports, native pointers, arbitrary Rustler resources, shader source,
unbounded maps, or recursive arbitrary terms.

RustQ owns repetitive contract constants, typed payloads, decoders, atoms, and
dispatch. Handwritten Rust owns actual GPUI rendering, platform support
detection, resource lookup, allocation, and lifecycle.
