# Native builds and deployment

GPUI ships a Rustler NIF backed by Rust GPUI and `gpui-component`. Native
packaging is validated separately from renderer-independent Elixir tests.

## Current platform status

Source builds and native window lifecycle behavior are validated on:

- `x86_64-unknown-linux-gnu` under X11 with Xvfb and Mesa Lavapipe;
- Apple silicon macOS with AppKit on ERTS's original process main thread;
- `x86_64-pc-windows-msvc` with the dedicated native GUI-thread host.

The published precompiled release target remains
`x86_64-unknown-linux-gnu`. Linux release artifacts are built on Ubuntu 22.04
and must not require GLIBC symbols newer than `GLIBC_2.35`; binaries built on a
newer development host are not release artifacts. macOS and Windows currently
require source builds. Linux ARM, musl, Windows ARM, and additional target
triples must not be claimed until their native build and interaction suites
pass.

## Source builds

The repository pins Rust 1.95.0 in `rust-toolchain.toml`, including Clippy and
rustfmt. Rustup selects it automatically from the project directory. This
version is required by the pinned GPUI revision, which uses standard-library
APIs unavailable in older compilers.

Native compilation is opt-in so renderer-independent consumers and tests do not
need a Rust toolchain. Enable it outside tests:

```elixir
# config/config.exs
config :gpui, build_native: config_env() != :test
```

`GPUI_BUILD_FROM_SOURCE=1` also enables the native build and forces source
compilation when a precompiled artifact exists. `GPUI_SKIP_NATIVE=1` explicitly
disables native compilation for tooling or packaging checks.

On Linux, install the platform libraries:

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

On macOS, install full Xcode and its Metal Toolchain. On Windows, use the MSVC
Rust target with Visual Studio 2022 Build Tools and a current Windows SDK.

Then compile normally:

```bash
PATH="$HOME/.cargo/bin:$PATH" mix compile
```

`yeslogic-fontconfig-sys` can load Fontconfig dynamically when development
metadata is unavailable:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix compile
```

## Headless and core feature sets

The native crate is checked in three configurations:

- core-only, without real GPUI;
- headless real GPUI, without desktop linker dependencies;
- desktop GPUI with component integration.

Consumer test environments configured with `build_native: config_env() != :test`
skip NIF compilation entirely, so `GPUI.Test` requires neither Rust nor platform
libraries. GPUI's own development suite still compiles and tests the core NIF
configuration explicitly. `ZED_HEADLESS=1`
selects real GPUI's headless backend for lifecycle work, but that backend cannot
open a platform window.

## Precompiled release flow

A version tag runs `.github/workflows/precompiled-nif.yml` through the shared
`elixir-vibe/actions` Rustler workflow. The workflow builds the Linux artifact,
attests it, attaches it to the GitHub release, and generates the mandatory
RustlerPrecompiled checksum manifest.

The expected release sequence is:

1. run `mix ci`;
2. run the native ExUnit window suite under Xvfb/Lavapipe on Linux;
3. run `RUST_FONTCONFIG_DLOPEN=1 mix gpui.release.check`;
4. build and attest the precompiled NIF from a version tag;
5. generate and commit `checksum-Elixir.GPUI.Native.exs` from the published bytes;
6. validate an anonymous no-Rust consumer;
7. publish the Hex package manually.

GPUI remains unpublished while its repository and release assets are private:
RustlerPrecompiled downloads anonymously, so private release assets prevent
consumer checksum validation and no-Rust installation.

## Release validation

`mix gpui.release.check` verifies:

- package contents, including native source fallback;
- documentation generation;
- Hex and RustSec dependency audits;
- that the MIT native artifact has no GPL-3 Rust dependencies;
- production source compilation from the built package.

The RustSec gate currently acknowledges `RUSTSEC-2026-0194` and
`RUSTSEC-2026-0195` for transitive `quick-xml` versions constrained by the
pinned GPUI platform stack. The `0.30` path is XCB/build metadata; the `0.39`
paths are Wayland code generation and local D-Bus introspection. They do not
parse GPUI snapshots or remote protocol payloads. New advisories still fail the
gate, and these exceptions must be removed when the upstream platform stack
accepts `quick-xml >= 0.41`.

Zed's Apache-licensed `sum_tree` uses only the `ztracing::instrument` surface,
but Zed declares its tracing facade as GPL-3. GPUI patches that facade with the
small `native/gpui/compat/ztracing` adapter, which re-exports the upstream
MIT/Apache `tracing` API. This keeps GPL-only tracing and logging crates out of
the linked NIF. Zed packages without per-crate license metadata are covered by
the repository's `LICENSE-APACHE`; `gpui-component` is Apache-2.0.

Run the release check with `cargo-audit` installed; release CI installs the
locked tool automatically. Release CI also uploads locked Cargo metadata and
the Mix dependency tree as a dependency inventory for each validation run.

It intentionally does not replace native E2E validation. Release claims should
cover only platforms tested with real windows and interaction.
