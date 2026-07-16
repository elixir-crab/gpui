# Native builds and deployment

GPUI ships a Rustler NIF backed by Rust GPUI and `gpui-component`. Native
packaging is validated separately from renderer-independent Elixir tests.

## Current platform status

The validated release target is:

- `x86_64-unknown-linux-gnu`

macOS, Windows, Linux ARM, musl, and additional target triples must not be
claimed until their native build and interaction suites pass.

## Source builds on Linux

Install Rust and the platform libraries:

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

Then compile normally:

```bash
PATH="$HOME/.cargo/bin:$PATH" mix compile
```

Set `GPUI_BUILD_FROM_SOURCE=1` to force source compilation when a precompiled
artifact exists.

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

The ordinary test environment uses the core configuration, so deterministic
session and remote tests do not load platform libraries. `ZED_HEADLESS=1`
selects real GPUI's headless backend for lifecycle work, but that backend cannot
open a platform window.

## Precompiled release flow

A version tag runs `.github/workflows/precompiled-nif.yml` through the shared
`elixir-vibe/actions` Rustler workflow. The workflow builds the Linux artifact,
attests it, attaches it to the GitHub release, and generates the mandatory
RustlerPrecompiled checksum manifest.

The expected release sequence is:

1. run `mix ci`;
2. run `mix test_e2e` under Xvfb/Lavapipe;
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
- dependency audit;
- production source compilation from the built package.

It intentionally does not replace native E2E validation. Release claims should
cover only platforms tested with real windows and interaction.
