# `GPUI.Template`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/template.ex#L1)

HEEx-style template support for GPUI.

This module intentionally reuses Phoenix LiveView's tag parser for the
HEEx-compatible tokenizer/tree builder, then compiles the parsed tree into
`%GPUI.Element{}` values instead of `%Phoenix.LiveView.Rendered{}`.

Lowercase tags are renderer primitives. Native components use `GPUI.UI` or
`GPUI.UI.Overlay`; their internal `ui_*` element tags are intentionally not a
public template surface.

# `compile`

```elixir
@spec compile(String.t(), Macro.Env.t(), keyword()) :: Macro.t()
```

# `sigil_GPUI`
*macro* 

Compiles a HEEx-style GPUI template into an element tree.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
