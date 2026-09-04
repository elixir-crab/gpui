# Platform support and development status

GPUI is a private, unreleased project. It has no supported historical public
API, wire payload, snapshot format, native artifact, or platform matrix.
Internal contracts may change directly while the architecture is being built.
Version fields validate the components that are running now; they do not imply
support for older project revisions.

## Runtime requirements

Development currently uses Elixir `~> 1.20` and the Rust toolchain pinned in
`rust-toolchain.toml`. Renderer-independent sessions, remote servers, and
`GPUI.Test` do not require a Rust toolchain, native library, or display server.
Native source builds require the pinned Rust toolchain.

These are current development requirements, not release guarantees.

## Platform validation

The `0.2.0-rc.2` precompiled targets are:

- `x86_64-unknown-linux-gnu` under X11, validated with real windows,
  interaction, and exact-window captures under Xvfb and Mesa Lavapipe;
- `aarch64-apple-darwin`, validated with real AppKit windows, interaction, and
  exact-window captures;
- `x86_64-pc-windows-msvc`, validated for artifact structure, package
  installation without Cargo, NIF loading, and runtime startup/shutdown.

Windows native-window compatibility depends on GPUI accepting an available
DXGI adapter. Native window creation with `0.2.0-rc.2` failed in tested
QEMU/QXL and VMware Fusion guests during DirectX renderer initialization. The
same failure remained after disabling VMware SVGA 3D and exposing Microsoft's
Basic Display Driver. This is a virtual-graphics compatibility boundary, not a
failure to select or load the precompiled NIF; physical Windows hardware and
GPU-passthrough environments have not yet been tested. Track the affected
configurations and upstream context in
[issue #3](https://github.com/elixir-crab/gpui/issues/3).

Linux ARM, musl, Intel macOS, Windows ARM-native ERTS, and other target triples
are not currently validated. An ARM Windows guest can run the published x86-64
ERTS and NIF through Windows emulation, but that does not constitute a native
ARM target.

See [Native builds and deployment](native-builds.html) for current prerequisites
and artifact details.

## Architectural boundary

The renderer-independent application pipeline is:

```text
GPUI.Application
→ GPUI.WindowSpec
→ GPUI.Session
→ GPUI.Snapshot
→ GPUI.Display
```

Application callback tuples, event payloads, topology errors, text coordinates,
and display errors remain authoritative in Elixir. Generated Rust files, native
renderer structs, GPUI entities, AccessKit internals, and RustQ code-generation
modules are implementation details.

Snapshots are ephemeral renderer-independent runtime messages, not durable
files. Applications persist domain state and render fresh snapshots.

## Remote protocol validation

`GPUI.Remote.Protocol.version/0` identifies the one wire shape implemented by
the current source tree. Negotiation requires that exact version and the
required peer capabilities so mismatched development processes fail before
mounting a session.

Capabilities describe optional behavior within the current wire shape. They do
not preserve older protocol revisions. When the protocol changes before the
first release, the implementation, fixtures, and version may be changed or
replaced directly; no historical peer version is retained unless a concrete
development need requires it.

Presentation support advertisement is informational and cannot change mount
eligibility or application topology.

## Native and accessibility boundaries

The native NIF and pinned GPUI stack are implementation details. Elixir code
must not depend on generated Rust layouts or native renderer symbols.

Accessibility claims are limited to the semantics and actions documented in
[Accessibility](accessibility.html). GPUI does
not claim arbitrary ARIA, DOM behavior, or uniform screen-reader behavior across
operating systems.

## Release policy

Public stability, semantic-versioning guarantees, deprecation periods, retained
wire versions, and the stable platform matrix remain pending release-candidate
feedback. Current release-candidate claims are limited to the evidence recorded
above; a published native archive does not by itself imply validated desktop
interaction on every machine with the same target triple.
