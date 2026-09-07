# `GPUI.Color`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/color.ex#L1)

Compile-time hexadecimal RGB and RGBA color literals.

`~RGB` accepts three or six hexadecimal digits. `~RGBA` accepts four or
eight hexadecimal digits. Short literals expand each digit, so `~RGB"abc"`
is equivalent to `{:rgb, 0xAABBCC}`.

These sigils deliberately omit a leading `#` because their names already
identify the literal as a hexadecimal color.

# `rgb`

```elixir
@type rgb() :: {:rgb, 0..16_777_215}
```

# `rgba`

```elixir
@type rgba() :: {:rgba, 0..4_294_967_295}
```

# `t`

```elixir
@type t() :: rgb() | rgba()
```

# `sigil_RGB`
*macro* 

Builds an opaque RGB literal from three or six hexadecimal digits.

# `sigil_RGBA`
*macro* 

Builds an RGBA literal from four or eight hexadecimal digits.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
