# Changelog

## Unreleased

### Breaking changes

- Physically moved conventional native declarations into
  `GPUI.Components.Schema.Declarations`; component builders now validate their
  provider-owned component struct through the shared core validator.
- Added `GPUI.Components.Schema` as the explicit owner used by conventional
  builders and statically composed native-host generation.
- Extracted conventional controls from `gpui` into the `gpui_components` package.
