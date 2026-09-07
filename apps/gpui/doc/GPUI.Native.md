# `GPUI.Native`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/native.ex#L1)

Availability information for the optional native GPUI backend.

Application code normally uses `GPUI.Runtime`, `GPUI.Display.Native`,
`GPUI.Image`, and `GPUI.Text.Buffer` rather than calling the native backend
directly. The latter three capabilities are provided by the `gpui_native`
package; without it, native-backed APIs return
`{:error, :native_backend_unavailable}`.

# `available?`

```elixir
@spec available?() :: boolean()
```

Reports whether the configured native backend loaded successfully.

# `compiled?`

> This function is deprecated. Use available?/0.

```elixir
@spec compiled?() :: boolean()
```

Deprecated alias for `available?/0`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
