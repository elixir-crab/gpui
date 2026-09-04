# Native builds and deployment

The published `gpui_native` package owns the RustlerPrecompiled loader and two
fixed, complete native hosts. `gpui` remains renderer-independent, while the
separately installed `gpui_components` package provides conventional component
schemas and Elixir builders for applications that select the `:gpui_component`
host.

## Native hosts

Both release hosts share one generated NIF boundary and one exact GPUI type
universe:

- `:vanilla` — a complete host built from vanilla GPUI and neutral primitives;
- `:gpui_component` — a complete host that statically links the separate
  `gpui-component` renderer library, assets, conventional controls, overlays,
  and theme integration.

Select one host at compile time:

```elixir
config :gpui_native, GPUI.Native, host: :vanilla
# or
config :gpui_native, GPUI.Native, host: :gpui_component
```

Exactly one final `cdylib` is loaded into `Elixir.GPUI.Native.NIF`. These are
alternative complete hosts, not a core dylib followed by a dynamically attached
component plugin. The component-capable host statically composes its Rust
libraries against the same pinned GPUI graph so windows, entities, resources,
and the event loop never cross a Rust shared-library ABI.

## Consumer compilation

On a supported precompiled target, compilation proceeds as follows:

1. Mix resolves `gpui_native` and its exact matching `gpui` release.
2. `gpui` compiles the generated backend-neutral `GPUI.Native` facade.
3. `gpui_native` reads the configured host at compile time.
4. `RustlerPrecompiled` selects the host variant, NIF ABI, and target triple.
5. It downloads the release archive, verifies its compressed SHA-256 against
   `checksum-Elixir.GPUI.Native.NIF.exs`, extracts it, and loads the NIF.
6. No RustQ, Cargo, Rust compiler, Node runtime, or source checkout is required.

RustQ runs only in the source umbrella. Its generated Rust decoders and Elixir
stubs/facade are committed before release.

## Current platform status

Source builds and native window lifecycle behavior are validated on:

- `x86_64-unknown-linux-gnu` under X11 with Xvfb and Mesa Lavapipe;
- `aarch64-apple-darwin` with AppKit on ERTS's original process main thread;
- `x86_64-pc-windows-msvc` with the dedicated native GUI-thread host.

Published precompiled hosts target `x86_64-unknown-linux-gnu`,
`aarch64-apple-darwin`, and `x86_64-pc-windows-msvc`. Linux release artifacts
are built on Ubuntu 22.04 and must not require GLIBC symbols newer than
`GLIBC_2.35`; macOS archives are built and load-tested on Apple silicon;
Windows archives are built with MSVC and load-tested on x86-64 Windows. Native
Windows applications must be launched in an interactive desktop session;
Windows OpenSSH sessions are suitable for package and NIF checks but not for
creating desktop windows. Intel macOS remains a source-build development target
until matching native runtime evidence and release artifacts pass.

## Source builds

`gpui_native` packages the complete native workspace at
`apps/gpui_native/native`. The repository pins Rust 1.95.0 in
`rust-toolchain.toml`.

Force source compilation with:

```bash
GPUI_BUILD_FROM_SOURCE=1 mix compile
```

Disable native compilation for renderer-independent tooling with:

```bash
GPUI_SKIP_NATIVE=1 mix compile
```

The application-level configuration is:

```elixir
config :gpui_native, build_native: config_env() != :test
```

On Linux install:

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

On macOS install full Xcode and its Metal Toolchain. On Windows use the MSVC
Rust target with Visual Studio 2022 Build Tools and a current Windows SDK.
`yeslogic-fontconfig-sys` can load Fontconfig dynamically:

```bash
RUST_FONTCONFIG_DLOPEN=1 GPUI_BUILD_FROM_SOURCE=1 mix compile
```

## Native development configurations

Repository CI checks:

- core-only, without real GPUI;
- headless real GPUI, without desktop linker dependencies;
- vanilla desktop GPUI without component integration;
- `gpui-component` desktop host with component integration;
- deterministic native-test and real desktop E2E configurations.

`ZED_HEADLESS=1` selects real GPUI's headless backend for lifecycle work, but
that backend cannot open a platform window.

## Precompiled release flow

The coordinated package tag `vVERSION` builds both host variants through
`.github/workflows/precompiled-nif.yml`. Release archives include the host in
the RustlerPrecompiled variant suffix: `--vanilla` or `--gpui-component`.
Checksums cover compressed `.tar.gz` bytes.

The release sequence is:

1. run `mix ci` from the umbrella root;
2. run native desktop ExUnit under Xvfb/Lavapipe on Linux;
3. run `RUST_FONTCONFIG_DLOPEN=1 mix gpui.release.check`;
4. tag the coordinated release and build both native hosts;
5. attest and publish the GitHub release archives;
6. generate `apps/gpui_native/checksum-Elixir.GPUI.Native.NIF.exs` from the
   published bytes;
7. validate a clean consumer with Cargo and Rust absent from `PATH`;
8. publish `gpui`, then `gpui_components`, then `gpui_native` to Hex.

The public packages initially use one coordinated version and exact sibling
requirements. Package versions remain distinct from versioned presentation
contracts such as `paint@1`.

## Release validation

Release validation verifies all three Hex package contents independently,
documentation, dependency audits, RustQ freshness, source-build fallback,
native host artifacts, and a no-Rust precompiled consumer. Linux GNU artifacts
retain the `GLIBC_2.35` ceiling.

Zed's Apache-licensed `sum_tree` uses only the `ztracing::instrument` surface,
but Zed declares its tracing facade as GPL-3. GPUI patches that facade with
`apps/gpui_native/native/compat/ztracing`, which re-exports the upstream
MIT/Apache `tracing` API. `gpui-component` is Apache-2.0.

Native E2E remains a separate evidence layer. Release claims cover only
platforms validated with real windows and interaction.
