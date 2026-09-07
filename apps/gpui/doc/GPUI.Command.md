# `GPUI.Command`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/../../../../apps/gpui/lib/gpui/command.ex#L1)

Declarative application command bound to a modified keyboard shortcut.

Command IDs are the same non-empty event names used by buttons and menus.
Shortcuts use `primary` for Command on macOS and Control elsewhere, with
optional `ctrl`, `alt`, and `shift` modifiers, for example `primary-r` or
`primary-shift-p`.

# `t`

```elixir
@type t() :: %GPUI.Command{id: String.t(), shortcut: String.t()}
```

# `new`

```elixir
@spec new(String.t(), String.t()) :: t()
```

Builds and validates one application command.

# `to_payload`

```elixir
@spec to_payload(t()) :: {String.t(), String.t()}
```

Converts a command into its renderer-independent protocol tuple.

# `validate_all!`

```elixir
@spec validate_all!([t()]) :: [t()]
```

Validates command count, IDs, shortcuts, and uniqueness.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
