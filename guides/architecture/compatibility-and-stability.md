# Compatibility and stability

GPUI is still a `0.x` package. Public APIs are being hardened, but semantic
versioning permits breaking changes before `1.0`. Release notes identify any
required source or configuration migrations.

## Runtime requirements

The package currently requires Elixir `~> 1.20`. Release validation uses the
Elixir and OTP versions declared by the repository workflows. Other OTP
versions are not claimed until they are included in that validation matrix.

Renderer-independent sessions, remote servers, and `GPUI.Test` do not require a
Rust toolchain, native library, or display server. Native source builds require
the Rust version pinned in `rust-toolchain.toml`; that file is included in the
Hex package so a clean packaged build selects the same compiler as the
repository.

## Platform support

The first stable distribution target is x86-64 GNU/Linux under X11. Its native
interaction suite runs under Xvfb with Mesa Lavapipe, and its precompiled NIF is
built on the documented Ubuntu baseline.

Apple silicon macOS and x86-64 Windows have validated source-build hosts but do
not yet have precompiled artifacts or the same hosted interaction coverage as
Linux. They must therefore be described as source-build preview targets rather
than equivalent packaged targets. Linux ARM, musl, Windows ARM, and other target
triples are unsupported until their build and interaction suites pass.

See [Native builds and deployment](native-builds.md) for prerequisites and the
release artifact process.

## Public Elixir contracts

The intended stable boundary is the renderer-independent application pipeline:

```text
GPUI.Application
→ GPUI.WindowSpec
→ GPUI.Session
→ GPUI.Snapshot
→ GPUI.Display
```

Public callback result tuples, event payloads, topology errors, text coordinate
rules, and display errors follow package semantic versioning. Modules and
functions documented by ExDoc are public unless their documentation explicitly
marks them experimental. Generated Rust files, native renderer structs, GPUI
entities, AccessKit node internals, and RustQ code-generation modules are not
consumer extension APIs.

Snapshot values are renderer-independent runtime messages, not a durable file
format. Applications should persist their own domain state and render a fresh
snapshot after upgrade.

## Remote protocol compatibility

`GPUI.Remote.Protocol.version/0` is the wire-protocol version. Connection
negotiation requires an exact version match and all required peer capabilities;
incompatible peers fail before mounting a session. Capabilities describe
features available within that exact protocol version and do not provide
forward compatibility by themselves.

A change that alters operation semantics or an existing serialized payload
incompatibly requires a protocol version increment. Additive behavior may use a
new negotiated capability when peers can safely operate without it. A package
release supports only the protocol version shipped by that release unless its
release notes explicitly state otherwise.

Unknown snapshot attributes must not be treated as a promise that older native
displays can render newer snapshots. Application servers and native display
clients should use compatible GPUI package versions.

## Native and accessibility boundaries

The native NIF and its pinned GPUI stack are implementation details of a GPUI
package release. Consumers should not link directly to native Rust renderer
symbols or depend on generated Rust layouts.

Accessibility claims are limited to the semantics and actions documented in
[Native accessibility boundaries](native-accessibility-boundaries.md). GPUI does
not claim arbitrary ARIA, DOM compatibility, or uniform screen-reader behavior
across operating systems.

## Deprecation policy

After `1.0`, planned public API removals should normally be deprecated for at
least one minor release before removal in the next major release. Immediate
changes remain possible for security defects, data loss, process crashes, or
contracts that cannot be implemented truthfully; those changes must be called
out prominently in the changelog.

Protocol versions and native artifact targets are compatibility boundaries, not
deprecation aliases. A superseded protocol or target is supported only when the
release documentation says so explicitly.
