# Getting started

GPUI keeps application state in ordinary Elixir processes and uses a display to
present serializable snapshots. A local application combines one or more
`GPUI.View` modules, a `GPUI.Application`, and an OTP-supervised `GPUI.Runtime`.

## Prerequisites

GPUI requires Elixir 1.20 or later. Native Linux builds require Rust and the XKB
development packages:

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

Enable the native display outside tests in your application's configuration:

```elixir
# config/config.exs
config :gpui, build_native: config_env() != :test
```

This keeps renderer-independent tests free of Rust and native-library
requirements. If `fontconfig.pc` is unavailable for a native build, compile
with:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix compile
```

## Run the examples

The getting-started examples form a short progression:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/01_hello_window.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/02_focus_timer.exs
RUST_FONTCONFIG_DLOPEN=1 mix run examples/getting_started/03_settings_form.exs
```

- **Hello Window** introduces a view, an application, and supervision.
- **Focus Timer** combines controlled events with periodic OTP messages.
- **Settings Form** demonstrates native controls, validation state, dynamic
  styling, and a controlled dialog.

Their application modules live under `examples/getting_started/support/`, so
they can also be loaded without starting a native display and tested through
`GPUI.Test`.

## Define a view

A view renders a `%GPUI.Element{}` tree from assigns. The `~GPUI` sigil accepts
HEEx-shaped tags, expressions, aliases, native components, and named slots.

```elixir
defmodule MyApp.WelcomeView do
  use GPUI.View

  @impl GPUI.View
  def render(_assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center gap-4 p-8 bg-slate-900">
      <text class="text-white text-3xl font-semibold">Hello from the BEAM</text>
      <text class="text-green-500">● Runtime connected</text>
    </div>
    """
  end
end
```

## Define an application

An application's `mount/1` callback returns its initial windows. Each root view
owns its own assigns.

```elixir
defmodule MyApp.Desktop do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "My application" do
         size(520, 320)
         root(MyApp.WelcomeView)
       end
     ]}
  end
end
```

Using the application module as a child starts a `GPUI.Runtime` with the native
display by default:

```elixir
Supervisor.start_link([MyApp.Desktop], strategy: :one_for_one)
```

Pass runtime options through the normal `{module, options}` child form when the
application needs mount arguments, a registered runtime, or a custom display:

```elixir
children = [
  {MyApp.Desktop,
   name: MyApp.Runtime,
   args: %{account_id: account_id},
   display: GPUI.Display.Native,
   poll_interval: 16}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Controlled events

Interactive native controls are controlled by root-view assigns:

```elixir
<GPUI.UI.input
  id="display-name"
  value={assigns.name}
  phx-change="name_changed"
/>
```

```elixir
@impl GPUI.View
def handle_event("name_changed", %{value: name}, assigns),
  do: {:noreply, %{assigns | name: name}}
```

Stable string IDs preserve native focus, editing state, popup state, and
selection across snapshots. Duplicate IDs are rejected before reaching a
display.

## Updates from OTP processes

Views can also handle application messages independently of pointer and keyboard
input:

```elixir
@impl GPUI.View
def handle_info(:tick, assigns),
  do: {:noreply, %{assigns | elapsed: assigns.elapsed + 1}}
```

A supervised worker delivers the message through the runtime:

```elixir
{:ok, _snapshot} = GPUI.Runtime.send_view(MyApp.Runtime, 1, :tick)
```

`send_view/3` updates the selected root view, synchronizes the display, and
publishes the same typed runtime update used by other state transitions. The
Focus Timer shows this pattern with a `GenServer` using `Process.send_after/3`.

## Test without a native window

The examples use normal application modules, so the same behavior can be tested
without a NIF or display server:

```elixir
defmodule MyApp.TimerTest do
  use GPUI.Test, async: true

  test "advances from an OTP message" do
    runtime = start_gpui!(GettingStarted.FocusTimer.App, args: %{seconds: 2})

    click(runtime, "start")
    send_view(runtime, :tick)

    assert %{remaining: 1, status: :running} = assigns(runtime)
  end
end
```

Continue with [Components and styling](components-and-styling.html),
[Overlays and menus](overlays-and-menus.html), [Testing GPUI applications](testing.html),
and [Sessions, runtimes, and displays](sessions-and-displays.html).
