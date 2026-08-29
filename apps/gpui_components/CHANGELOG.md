# Changelog

## Unreleased

### Breaking changes

- Added the owner-local `native/` source root for the future component Rust
  crate and included its generated projection in the package payload.
- Physically moved conventional native declarations into
  `GPUI.Components.Schema.Declarations`; component builders now validate their
  provider-owned component struct through the shared core validator.
- Added `GPUI.Components.Schema` as the explicit owner used by conventional
  builders and statically composed native-host generation.
- Extracted conventional controls from `gpui` into the `gpui_components` package.
