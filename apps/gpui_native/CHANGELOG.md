# Changelog

## Unreleased

### Breaking changes

- Extracted native loading from `gpui` into this separately installed package.
- Native builds are complete immutable `:vanilla` or `:gpui_component` hosts;
  `GPUI.Native.host_info/0` reports the loaded artifact identity.
