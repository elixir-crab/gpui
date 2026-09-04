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

The intended first distribution target is x86-64 GNU/Linux under X11. Native
interaction tests run under Xvfb with Mesa Lavapipe when a Linux host is
available.

Apple silicon macOS and x86-64 Windows are precompiled targets with native
build, artifact inspection, NIF loading, and runtime startup evidence. Windows
native windows must run in an interactive desktop session rather than a Windows
OpenSSH session. Linux ARM, musl, Intel macOS, Windows ARM, and other target
triples are not currently validated.

See [Native builds and deployment](native-builds.html) for current prerequisites
and the proposed artifact process.

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
wire versions, supported artifacts, and a platform matrix will be defined when
the first release is prepared. Until then, optimize for a coherent design,
truthful behavior, and strong tests rather than hypothetical compatibility.
