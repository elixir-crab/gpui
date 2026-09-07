# `GPUI.ResourceRef`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/resource_ref.ex#L1)

Reference to a remote/display resource such as a raster image.

# `t`

```elixir
@type t() :: %GPUI.ResourceRef{id: String.t(), type: :raster}
```

# `new`

```elixir
@spec new(String.Chars.t(), :raster) :: t()
```

# `to_payload`

Converts a resource reference into its renderer-independent payload.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
