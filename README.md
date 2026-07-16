# GPUI

Elixir/OTP bindings and DSL experiments for [GPUI](https://www.gpui.rs).

The package name is `gpui`, with public modules under `GPUI`.

## Current direction

- Elixir views render serializable `%GPUI.Element{}` trees.
- `GPUI.Session` owns renderer-independent windows, view assigns, resources, and rendered snapshots.
- `GPUI.Runtime` composes a session with a local `GPUI.Display`.
- Rust/Rustler provides `GPUI.Display.Native`.
- Native input uses GPUI `EntityInputHandler` with focus, cursor/selection paint, clipboard, IME hooks, and UTF-16/UTF-8 offset handling.
- `GPUI.UI` exposes controlled native controls backed by Longbridge's `gpui-component`.
- Remote app/display workflows use `SafeRPC` over framed TCP/SSL for safe ETF RPC, request IDs, timeouts, and capability checks.
- GPUI owns the app operation contract in `GPUI.Remote.Protocol`.
- `GPUI.Remote.Server` isolates every application session and requires protocol `hello` before other operations.
- RustQ generates native NIF glue from project specs as the surface grows.

## Installation

After publication:

```elixir
def deps do
  [
    {:gpui, "0.1.1"}
  ]
end
```

Version 0.1 provides a checksummed precompiled NIF for x86-64 GNU/Linux. Other
targets fall back to the packaged Rust source and require a Rust toolchain plus
the platform development libraries. Set `GPUI_BUILD_FROM_SOURCE=1` to force that
path explicitly.

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

Set `RUST_FONTCONFIG_DLOPEN=1` when `fontconfig.pc` is unavailable. macOS,
Windows, Linux ARM, and musl artifacts remain pending platform validation.

## Development

```sh
mix deps.get
mix test_unit
mix test_integration
mix ci
mix test_e2e
```

Tests are split by intent:

- `test/gpui/**` contains unit-focused tests.
- `test/integration/**` contains runtime, transport, and remote-flow integration tests.
- `test/e2e/**` contains real native-window tests run under Xvfb.

Applications can use the packaged ExUnit helpers for deterministic tests without
native libraries or a display server:

```elixir
defmodule CounterTest do
  use GPUI.Test, async: true

  test "increments" do
    runtime = start_gpui!(CounterApp)

    assert %{count: 0} = assigns(runtime)
    click(runtime, "increment")
    assert %{count: 1} = assigns(runtime)

    change(runtime, "name_changed", "Ada")
    select(runtime, "language_changed", "elixir")
    search(runtime, "framework_searched", "live")
    slide(runtime, "volume_changed", 75.0)
    assert %{name: "Ada", language: "elixir", query: "live", volume: 75.0} = assigns(runtime)
    assert %{type: :ui_input} = runtime |> tree() |> find!(id: "name")
  end
end
```

`GPUI.Test.Display` is also public for tests that need direct control over the
display boundary or synchronized snapshot history.

Useful verification gates:

```sh
mix test_unit
mix test_integration
mix rustq.gen --check
mix rust.fmt --check
mix rust.check
mix rust.clippy
mix rust.headless.clippy
mix rust.core.clippy
mix rust.e2e.clippy
mix test_e2e
mix gpui.release.check
```

The test environment compiles the NIF without `real-gpui`, so pure session,
runtime, and remote tests do not require desktop system libraries. Rust gates
cover three configurations: core-only, headless real GPUI, and the desktop
Wayland/X11 build. Setting `ZED_HEADLESS=1` selects the real-GPUI headless build
without desktop linker dependencies. Headless GPUI can exercise application
lifecycle but cannot open a platform window.

For real native-window verification on a server, install the minimal X11 build
and virtual display dependencies, then run the checked-in smoke suite:

```bash
sudo apt-get install xvfb xdotool libxkbcommon-dev libxkbcommon-x11-dev
mix test_e2e
```

The suite runs the ExUnit tests in `test/e2e/**` against real GPUI windows under
Xvfb using Mesa's Lavapipe software renderer. It verifies process-global loop
ownership, duplicate window IDs across runtimes, acknowledged lifecycle commands,
snapshot shrink, runtime shutdown isolation, and native display operation through
the TCP remote API. XTest-driven pointer and keyboard input additionally proves
button hit testing, input focus, change/key events, rapid editing, backspace,
selection, clipboard operations, controlled-value replacement, multiple input
isolation, rerendering, and user-requested window closure. No desktop environment
or window manager is required.

The Rust crate is named `gpui_nif` only to avoid Cargo ambiguity with upstream
`gpui`; the Hex package and public API remain `gpui` / `GPUI.*`.

## Precompiled release flow

Pushing a version tag such as `v0.1.0` runs
`.github/workflows/precompiled-nif.yml` through the organization-standard
`elixir-vibe/actions` Rustler release workflow. It builds and attests the Linux
NIF, attaches it to the GitHub release, then generates the mandatory
`checksum-Elixir.GPUI.Native.exs` manifest from those published bytes. Download
that checksum into the repository root before building the Hex package; the
package configuration includes it automatically. Hex publication remains a
manual step after `mix gpui.release.check` passes.

## Supported UI surface

Templates support `div`, `button`, `span`, `scroll`, `list`, `item`, `icon`,
`input`, `img`, and `text`. Text and image nodes retain their own generated
native styles rather than relying only on parent styles.

`GPUI.UI.button/1`, `GPUI.UI.checkbox/1`, `GPUI.UI.input/1`,
`GPUI.UI.select/1`, `GPUI.UI.combobox/1`, `GPUI.UI.switch/1`,
`GPUI.UI.radio_group/1`, `GPUI.UI.accordion/1`, `GPUI.UI.tabs/1`,
`GPUI.UI.slider/1`, `GPUI.UI.Overlay.tooltip/1`,
`GPUI.UI.Overlay.popover/1`, and `GPUI.UI.Overlay.dialog/1` render real
[`gpui-component`](https://github.com/longbridge/gpui-component) controls.
Interactive values are controlled by Elixir assigns, and native components
require stable string IDs. Stateful component entities are reconciled by kind
and ID so focus, selection, open
state, and editing state survive rerenders. Duplicate IDs are rejected before a
snapshot crosses the display boundary:

```elixir
~GPUI"""
<div class="flex flex-col gap-4">
  <GPUI.UI.button
    id="save"
    label="Save"
    variant="primary"
    loading={assigns.saving}
    phx-click="save"
  />
  <GPUI.UI.checkbox
    id="remember"
    label="Remember me"
    checked={assigns.remember}
    phx-change="remember"
  />
  <GPUI.UI.input
    id="name"
    value={assigns.name}
    placeholder="Name"
    cleanable={true}
    phx-change="name_changed"
  />
  <GPUI.UI.select
    id="language"
    value={assigns.language}
    options={[{"Rust", "rust"}, {"Elixir", "elixir"}]}
    phx-change="language_changed"
  />
  <GPUI.UI.combobox
    id="framework"
    value={assigns.framework}
    options={assigns.framework_options}
    phx-change="framework_changed"
    phx-search="framework_searched"
  />
  <GPUI.UI.switch
    id="notifications"
    label="Notifications"
    checked={assigns.notifications}
    phx-change="notifications_changed"
  />
  <GPUI.UI.radio_group
    id="plan"
    value={assigns.plan}
    options={[
      {"Free", "free"},
      %{label: "Pro", value: "pro", disabled: true}
    ]}
    phx-change="plan_changed"
  />
  <GPUI.UI.accordion
    id="details"
    expanded={assigns.expanded}
    phx-change="details_changed"
  >
    <GPUI.UI.accordion_item id="account" title="Account">
      <text>Account details</text>
    </GPUI.UI.accordion_item>
  </GPUI.UI.accordion>
  <GPUI.UI.tabs
    id="section"
    value={assigns.section}
    options={[{"General", "general"}, {"Advanced", "advanced"}]}
    phx-change="section_changed"
  />
  <GPUI.UI.slider
    id="volume"
    value={assigns.volume}
    min={0}
    max={100}
    step={5}
    phx-change="volume_changed"
    phx-release="volume_released"
  />
</div>
"""
```

Aliases keep component-heavy templates concise, and overlays use ordinary HEEx
named slots instead of synthetic slot components:

```elixir
alias GPUI.UI
alias GPUI.UI.Overlay

~GPUI"""
<div class="flex flex-col gap-4">
  <Overlay.tooltip id="save-help" delay={250}>
    <:trigger><UI.button id="save" label="Save" /></:trigger>
    <:content>Save the current document</:content>
  </Overlay.tooltip>

  <Overlay.popover id="account-menu" open={assigns.menu_open} phx-change="menu_changed">
    <:trigger>
      <UI.button id="account-trigger" label="Account" />
    </:trigger>
    <:content>
      <text>Account settings</text>
    </:content>
  </Overlay.popover>

  <Overlay.dialog
    id="settings-dialog"
    open={assigns.dialog_open}
    title="Settings"
    width={520}
    phx-change="dialog_changed"
  >
    <:trigger><UI.button id="settings-trigger" label="Settings" /></:trigger>
    <:content><UI.input id="display-name" value={assigns.name} /></:content>
  </Overlay.dialog>
</div>
"""
```

Tooltip content is textual and uses the upstream native tooltip lifecycle;
`delay` is expressed in milliseconds. Popover triggers support pointer and
Enter/Space activation. Escape and outside clicks request closure, and focus
returns to the prior trigger. Set `closable={false}` to disable outside-click
dismissal. Dialogs use the same controlled `open` contract, trap focus, restore
prior focus, and accept arbitrary GPUI content; their `:trigger` slot is optional
for programmatically opened dialogs.

Checkbox and switch change events carry a boolean `:value`; input, select,
radio-group, and combobox change events carry their controlled `:value`. Combobox search events carry the
current query. Tab changes carry the selected string value, while accordion
changes carry the ordered list of expanded item IDs. Slider change events are
continuous and release events fire once pointer interaction ends. Select,
combobox, radio-group, and tab options accept strings, `{label, value}` tuples, or
`%{label: label, value: value}` maps; radio maps may also set `disabled`.
Switches activate with Enter or Space. Radio groups use a roving tab stop and
Left/Up/Right/Down navigation, skipping disabled options.
Button variants are `default`,
`primary`, `secondary`, `danger`, `warning`, `success`, `info`, `ghost`, `link`,
and `text`; component sizes are
`xs`, `sm`, `md`, and `lg`.

Native component themes are process-global and refresh every native window:

```elixir
{:ok, display} = GPUI.Display.Native.start_link(theme: :dark)
:ok = GPUI.Display.Native.set_theme(display, :light)
```

The Tailwind-compatible normalizer covers display and flex layout, wrapping,
alignment, growth and shrink, colors, typography, opacity, spacing, dimensions,
minimum/maximum dimensions, borders, and radius. Unsupported classes remain in
the serialized `class` attribute instead of being silently reinterpreted.

## Examples

Build the native display:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix compile
```

Run a local native counter:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/counter.exs
```

Run a local native image using a runtime resource cache and `%GPUI.ResourceRef{}`:

```sh
PATH="$HOME/.cargo/bin:$PATH" mix run examples/resource_ref_image.exs
```

Run the two-terminal remote app/display workflow:

```sh
# Terminal 1: remote OTP app server
GPUI_APP_PORT=5050 mix run examples/remote_app_server.exs

# Terminal 2: local display client
GPUI_APP_HOST=127.0.0.1 GPUI_APP_PORT=5050 PATH="$HOME/.cargo/bin:$PATH" mix run examples/local_display_client.exs
```

Remote app/display can also run over TLS/SSL. The server expects a certificate and key:

```sh
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CERTFILE=/path/to/server.pem \
GPUI_REMOTE_SSL_KEYFILE=/path/to/server.key \
GPUI_APP_PORT=5050 \
mix run examples/remote_app_server.exs
```

The display client expects the CA certificate and optional SNI name:

```sh
GPUI_REMOTE_SSL=1 \
GPUI_REMOTE_SSL_CACERTFILE=/path/to/ca.pem \
GPUI_REMOTE_SSL_SERVER_NAME=localhost \
GPUI_APP_HOST=localhost \
GPUI_APP_PORT=5050 \
mix run examples/local_display_client.exs
```
