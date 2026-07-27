# Music library

Afterglow is a polished, deterministic desktop music-library example. It shows
how a larger GPUI application can keep navigation, search, selection, playback,
seek position, and volume as controlled Elixir state while native GPUI renders
the window and controls.

Run it from the repository root:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/music_library/run.exs
```

For state-preserving Elixir source reload while editing the example:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.dev examples/music_library/run.exs
```

The example includes:

- a persistent library and playlist sidebar;
- controlled search and sort controls;
- an accessible virtualized track list;
- selected-track metadata and a now-playing panel;
- previous, play/pause, next, seek, and volume controls;
- responsive viewport filling through the application-declared `grow` root.

The catalog is deterministic and does not read media files or access the
network, so the same states can be tested and captured reliably.
