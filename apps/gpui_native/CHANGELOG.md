# Changelog

## Unreleased

### Compatibility

- Documented that native Windows windows require an interactive desktop session;
  OpenSSH sessions remain suitable for package and NIF validation.

## 0.2.0-rc.2 - 2026-09-03

### Added

- Added precompiled NIFs for Apple silicon macOS and x86-64 Windows MSVC, with
  vanilla and `gpui-component` variants for each platform.

### Compatibility

- Added no-Cargo native-host loading on Apple silicon macOS and x86-64 Windows
  alongside the existing x86-64 GNU/Linux support.

## 0.2.0-rc.1 - 2026-09-02

### Breaking changes

- Extracted native loading from `gpui` into this separately installed package.
- Native builds are complete immutable `:vanilla` or `:gpui_component` hosts;
  `GPUI.Native.host_info/0` reports the loaded artifact identity.

### Added

- Added separate verified precompiled archives for vanilla and
  `gpui-component` hosts.
- Added source fallback and no-Cargo loading for supported precompiled
  consumers.
- Added native application identity propagation and typed host capability
  inspection.

### Changed

- Native source packages resolve `gpui_core` and `gpui_components` from their
  coordinated Hex package sources while preserving host-specific dependency
  graphs.

### Compatibility

- Precompiled x86-64 Linux hosts target NIF ABI 2.15 and require no GLIBC newer
  than 2.35.
