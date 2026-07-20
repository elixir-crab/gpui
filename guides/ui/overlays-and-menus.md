# Overlays and menus

`GPUI.UI.Overlay` contains controlled native overlays. Public templates use
ordinary HEEx named slots; internal slot nodes remain an implementation detail.

```elixir
alias GPUI.UI
alias GPUI.UI.Overlay
```

## Tooltips

Tooltips accept one arbitrary trigger and one textual content slot:

```elixir
<Overlay.tooltip id="save-help" delay={250} hoverable={true}>
  <:trigger><UI.button id="save" label="Save" /></:trigger>
  <:content>Save the current document</:content>
</Overlay.tooltip>
```

`delay` is measured in milliseconds from `0` through `60_000`. Tooltip content
is intentionally textual because the upstream native tooltip owns a separate
view lifecycle.

## Popovers

Popovers accept arbitrary GPUI trees in both named slots:

```elixir
<Overlay.popover
  id="account-popover"
  open={assigns.account_open}
  anchor="top_left"
  phx-change="account_open_changed"
>
  <:trigger><UI.button id="account-trigger" label="Account" /></:trigger>
  <:content>
    <div class="w-[220px] p-3">
      <text>Account settings</text>
    </div>
  </:content>
</Overlay.popover>
```

Popover state is controlled by `open`. Pointer interaction and Enter/Space can
request a state change. Escape and outside clicks dismiss closable popovers and
restore focus. Set `closable={false}` to disable outside-click dismissal.

Anchors are `top_left`, `top_center`, `top_right`, `bottom_left`,
`bottom_center`, `bottom_right`, `left_center`, and `right_center`.

## Dialogs

Dialogs are modal and can be opened by a trigger or entirely through assigns:

```elixir
<Overlay.dialog
  id="settings-dialog"
  open={assigns.dialog_open}
  title="Settings"
  width={520}
  phx-change="dialog_open_changed"
>
  <:trigger><UI.button id="settings-trigger" label="Settings" /></:trigger>
  <:content>
    <UI.input id="display-name" value={assigns.name} phx-change="name_changed" />
  </:content>
</Overlay.dialog>
```

The content slot accepts arbitrary GPUI content. Native dialogs trap focus,
restore prior focus, and support configurable Escape, overlay dismissal, close
buttons, and width. The trigger slot is optional for programmatic dialogs.

## Dropdown menus

Dropdown menus use an arbitrary trigger and repeated textual item slots:

```elixir
<Overlay.dropdown_menu
  id="file-menu"
  open={assigns.file_menu_open}
  phx-change="file_menu_open_changed"
  phx-select="file_menu_selected"
>
  <:trigger><UI.button id="file-trigger" label="File" /></:trigger>
  <:item value="new">New file</:item>
  <:item value="open" checked={assigns.recent}>Open recent</:item>
  <:item value="delete" disabled={true}>Delete</:item>
</Overlay.dropdown_menu>
```

Item values must be non-empty and unique. Selection emits the value through
`phx-select`; open-state changes use `phx-change`. The upstream popup menu
provides menu roles, checked and disabled semantics, arrow-key navigation,
Enter confirmation, Escape dismissal, outside-click dismissal, and focus
restoration.

A typical view handles both events explicitly:

```elixir
def handle_event("file_menu_open_changed", %{value: open}, assigns),
  do: {:noreply, %{assigns | file_menu_open: open}}

def handle_event("file_menu_selected", %{value: action}, assigns) do
  {:noreply, %{assigns | file_menu_open: false, selected_action: action}}
end
```

## Controlled reconciliation

Elixir assigns remain authoritative, while persistent native registry entries
preserve transient state between snapshots. A local interaction is applied
immediately and recorded until the corresponding controlled snapshot arrives.
Stale snapshots are ignored rather than visibly undoing the interaction.

Removing an overlay from the tree removes its registry entry. Stable IDs must
not be reused for a different component kind in the same tree.
