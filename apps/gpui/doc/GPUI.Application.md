# `GPUI.Application`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/application.ex#L1)

Behaviour and DSL for OTP-supervised GPUI applications.

`mount/1` declares a session's initial windows. Interactive state belongs to
each root view's assigns rather than an unused application-level state value.
Window blocks may bind stable command IDs with `shortcut/2`; native and remote
displays dispatch them to the same view handlers used by buttons and menus.

# `identity`
*optional* 

```elixir
@callback identity() :: GPUI.Application.Identity.t()
```

# `mount`

```elixir
@callback mount(term()) :: {:ok, [GPUI.WindowSpec.t()]}
```

Builds the initial renderer-independent window set for a session.

# `chrome`
*macro* 

Declares whether the window uses system or application-rendered content chrome.

# `identity`

```elixir
@spec identity(module()) :: GPUI.Application.Identity.t() | nil
```

Returns and validates an application's declared identity, when present.

# `min_size`
*macro* 

Declares a minimum window size inside `window`.

# `resizable`
*macro* 

Declares whether the native window can be resized by the user.

# `root`
*macro* 

Declares a root view inside `window`.

# `shortcut`
*macro* 

Binds an application command to a modified shortcut inside `window`.

# `size`
*macro* 

Declares a window size inside `window`.

# `window`
*macro* 

Builds a window specification from a DSL block.

# `window`
*macro* 

Builds a keyed window specification from a DSL block.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
