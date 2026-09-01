# Changelog

## Unreleased

## 0.2.0-rc.1 - 2026-09-02

### Breaking changes

- Extracted conventional controls from `gpui` into this separately installed
  package.
- Conventional declarations are exposed through `GPUI.Components.Schema` and
  compose explicitly with the neutral `gpui` schema for component native hosts.

### Added

- Added public declarative controls and shell components for actions, forms,
  navigation, overlays, status surfaces, collections, code, rich text, and
  virtualized content.
- Added accessible sidebar items, status items, separators, switches, sliders,
  radio groups, and focused component-gallery stories.
- Added inspectable component capabilities and typed component event contracts.

### Changed

- Switch, slider, and radio rendering now use package-owned native component
  implementations backed by the statically linked `gpui-component` host.
- Component styles preserve schema-owned layout and presentation values across
  the Elixir-to-native boundary.
