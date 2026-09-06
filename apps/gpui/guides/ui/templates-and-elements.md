# Templates and elements


`GPUI.UI` provides controlled Elixir components backed directly by
`gpui-component`. Components build ordinary `%GPUI.Element{}` data; the native
display owns GPUI entities, callbacks, focus, and transient interaction state.

## Aliases and templates

Component aliases are resolved from the calling module:

```elixir
alias GPUI.UI

~GPUI"""
<div class="flex flex-col gap-4 p-4">
  <UI.button id="save" label="Save" variant="primary" phx-click="save" />
  <UI.checkbox
    id="remember"
    label="Remember me"
    checked={assigns.remember}
    phx-change="remember_changed"
  />
</div>
"""
```

Lowercase tags are renderer primitives such as `div`, `text`, `input`, and
`img`. Native components are always called through `GPUI.UI` or
`GPUI.UI.Overlay`; internal tags such as `<ui_button>` are rejected at template
compile time instead of bypassing their public builder contracts. Duplicate
attributes and unknown tags are also compile errors.

Component events use `phx-*` attributes because the template and callback
vocabulary intentionally follows Phoenix conventions familiar to Elixir users;
there is no Phoenix process or browser event behind them. The attribute value is
a stable application event name delivered to the `GPUI.View` `handle_event/3`
callback.

Every native component requires a stable, non-empty string `id`. Component
builders reject unknown options and validate schema-backed attributes and event
names before a snapshot reaches any display, including `GPUI.Test.Display`.
Invalid values raise an `ArgumentError` that names the component, attribute,
expected type or enum, and received value—for example,
`ui_button :disabled must be a boolean; got: "yes"`.

Each builder's ExDoc entry includes a schema-derived option table showing types,
required attributes and events, enum values, and defaults. The corresponding
named option type—for example `t:GPUI.UI.slider_options/0` or
`t:GPUI.UI.Overlay.dialog_options/0`—provides the same contract to editors,
Dialyzer, and library consumers. Both projections come from the shared internal
component schema, so native decoding, validation, types, and documentation
cannot drift into separate option registries.
