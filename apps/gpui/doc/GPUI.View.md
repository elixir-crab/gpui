# `GPUI.View`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/view.ex#L1)

Behaviour for Elixir-rendered GPUI views.

Views render from assigns, handle native input through `handle_event/3`, and
receive supervised application updates through `handle_info/2` when a caller
uses `GPUI.Runtime.send_view/3`.

# `callback_result`

```elixir
@type callback_result() ::
  {:noreply, map()}
  | {:close, map()}
  | {:open_window, GPUI.WindowSpec.t(), map()}
  | {:close_window, GPUI.WindowSpec.key() | pos_integer(), map()}
```

# `window_event`

```elixir
@type window_event() :: :close_request | :focus | :blur
```

# `handle_event`

```elixir
@callback handle_event(String.t(), GPUI.Event.payload(), map()) :: callback_result()
```

# `handle_info`
*optional* 

```elixir
@callback handle_info(term(), map()) :: callback_result()
```

# `handle_window_event`
*optional* 

```elixir
@callback handle_window_event(window_event(), GPUI.Event.payload(), map()) ::
  {:noreply, map()} | {:close, map()}
```

# `render`

```elixir
@callback render(map()) :: GPUI.Element.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
