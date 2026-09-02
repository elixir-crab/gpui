# VibeKit quality gate

## Development

```sh
mix deps.get
mix ci
```

## Conventions

- Use `mix ci` for the full validation suite before finishing changes.
- For Phoenix/web apps, keep Phoenix's generated guidance, but treat this VibeKit section as the final quality gate.
- For non-web Elixir projects, VibeKit is the default project baseline.
- Keep changes small, tested, and formatted.

## Test structure

- Put focused unit tests in `test/gpui/` and cross-process or transport tests in
  `test/integration/`.
- Put real platform-window and operating-system interaction tests in `test/e2e/`.
  Keep environment orchestration in Mix tasks and reusable drivers in
  `test/support/`; examples are documentation, not test runners.
- Run native E2E coverage as ordinary ExUnit under Xvfb/Lavapipe:
  `MIX_ENV=e2e xvfb-run -a dbus-run-session -- mix test --only e2e test/e2e`.
  It must not require a desktop environment or window manager.
- Assert behavior and generated output. Do not enforce architecture with source
  greps or policy-shaped ExUnit tests; use Reach, Credo, ExDNA, or schema-driven
  behavioral coverage.

## Precompiled release invariants

- A release tag is immutable. Never delete, recreate, move, or force-push a
  release tag.
- The tag points to the validated release source commit before generated
  RustlerPrecompiled checksums are committed.
- The tagged workflow builds and publishes both complete native hosts:
  `vanilla` and `gpui-component`.
- Generate `checksum-Elixir.GPUI.Native.NIF.exs` only after both tagged archives
  have been published successfully.
- Commit the checksum manifest as a follow-up commit on `main`. Do not retag
  that commit; it does not need a release tag.
- Publish `gpui_native` from the checksum-bearing follow-up commit while keeping
  the same package version as the immutable tagged artifacts.
- If tagged artifacts, checksums, or release metadata are wrong, abandon that
  release version and prepare the next release candidate or patch version.
  Never repair a published release by moving its tag.
- Before publishing `gpui_native`, run both no-Cargo consumer checks:
  `mix gpui.test.precompiled --host vanilla` and
  `mix gpui.test.precompiled --host gpui_component`.
- Publish coordinated Hex packages in dependency order: `gpui`, then
  `gpui_components`, then `gpui_native`.
