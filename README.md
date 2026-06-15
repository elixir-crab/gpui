# GPUI

Elixir/OTP bindings and DSL experiments for [GPUI](https://www.gpui.rs).

The package name is `gpui`, with public modules under `GPUI`.

## Current direction

- Elixir views render serializable `%GPUI.Element{}` trees.
- OTP owns lifecycle through `GPUI.Runtime`.
- Rust/Rustler provides native validation and future headless utilities.
- A Rust GPUI host process will own the platform event loop.
- RustQ will generate protocol code from `GPUI.CommandSpec` as the surface grows.

## Installation

After publication:

```elixir
def deps do
  [
    {:gpui, "~> 0.1.0"}
  ]
end
```

## Development

```sh
mix deps.get
mix ci
```
