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
