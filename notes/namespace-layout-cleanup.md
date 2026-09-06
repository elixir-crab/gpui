# Namespace and file-layout cleanup

## Package modules

- [x] Align `GPUI.Display.Native` with `gpui/display/native.ex`.
- [x] Place generated native modules under `gpui/native/`.
- [x] Rename template internals under `GPUI.Template.*`.
- [x] Rename schema documentation projection to `GPUI.Schema.Component.Docs`.
- [x] Move collection validation under `GPUI.UI.Collection.Validation`.
- [x] Rename runtime subscriptions and display polling under their owning domains.
- [x] Disambiguate native test driver/session/error modules.
- [x] Normalize remote connection, server, session, and protocol submodules.
- [x] Separate consumer reload support from repository-maintainer tooling.

## Code generation

- [x] Nest definition, macro, boundary, and adapter modules under their owning codegen domains.
- [x] Align codegen files with module ownership where practical while keeping tightly coupled generator/macros colocated.
- [x] Regenerate all RustQ outputs and verify freshness.

## Tests

- [x] Align test module namespaces with their paths.
- [x] Group example tests under `GPUI.Examples`.
- [x] Move maintainer tests out of the `codegen/` folder.
- [x] Split oversized test responsibilities into clearly named domain files where independent fixtures permit it; retain cohesive fixture-heavy suites to avoid duplicated setup modules.
- [x] Keep test-local fixture views/apps nested in their owning test module.

## Validation

- [x] No `@moduledoc false` or `@doc false` in package source.
- [x] Formatting and generated files are current.
- [x] Focused tests and exact package/docs checks pass.
- [x] `mix ci` passes from a clean build.
