# `GPUI.Tailwind`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/tailwind.ex#L1)

Small Tailwind-compatible class normalizer for GPUI element styles.

This intentionally starts with a constrained subset that maps cleanly to GPUI.
Unknown classes are preserved under `:class` by callers and handled according
to the `:unknown_classes` application setting: `:warn` (the development
default), `:error`, or `:keep`.

# `result`

```elixir
@type result() :: %{style: keyword(), unknown: [String.t()]}
```

# `handle_unknown!`

```elixir
@spec handle_unknown!([String.t()]) :: :ok
```

Applies the configured warning or error policy to unsupported classes.

# `normalize`

```elixir
@spec normalize(String.t() | [String.t()] | nil) :: result()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
