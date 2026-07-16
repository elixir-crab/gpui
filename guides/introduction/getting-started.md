# Getting started

GPUI keeps application state in ordinary Elixir processes and uses a display to
present serializable snapshots. A local application normally combines a
`GPUI.Application`, one or more `GPUI.View` modules, and `GPUI.Runtime` under an
OTP supervisor.

## Prerequisites

GPUI requires Elixir 1.20 or later. The currently validated native target is
x86-64 GNU/Linux. A source build also requires Rust and the XKB development
packages:

```bash
sudo apt-get install libxkbcommon-dev libxkbcommon-x11-dev
```

If `fontconfig.pc` is unavailable, compile with:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix compile
```

See [Native builds and deployment](native-builds.html) for supported artifacts,
source fallback, and release constraints.

## Define a view

A view renders a `%GPUI.Element{}` tree from assigns and handles named events.
The `~GPUI` sigil accepts HEEx-shaped tags, expressions, aliases, components,
and named slots.

```elixir
defmodule MyApp.CounterView do
  use GPUI.View

  @impl GPUI.View
  def render(assigns) do
    ~GPUI"""
    <div class="flex flex-col items-center justify-center gap-3 p-4 bg-slate-900">
      <text class="text-white text-2xl">Count: {assigns.count}</text>
      <GPUI.UI.button id="increment" label="Increment" phx-click="increment" />
    </div>
    """
  end

  @impl GPUI.View
  def handle_event("increment", _event, assigns),
    do: {:noreply, %{assigns | count: assigns.count + 1}}
end
```

Interactive values are controlled. The view updates its assigns in response to
an event, then GPUI reconciles the resulting snapshot with persistent native
state.

## Define an application

The application `mount/1` callback returns the initial window specifications. Each root
view owns its own assigns.

```elixir
defmodule MyApp.Desktop do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Counter" do
         size(320, 240)
         root(MyApp.CounterView, count: 0)
       end
     ]}
  end
end
```

## Supervise the runtime

Using a GPUI application module as a child starts `GPUI.Runtime` with the native
display by default:

```elixir
children = [
  {MyApp.Desktop, poll_interval: 16}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

The polling interval controls how frequently native events are drained. Tests
can set it to `nil` and inject events explicitly through `GPUI.Test`.

## Controlled events

Native components emit payloads with a `:value` field:

```elixir
<GPUI.UI.input
  id="name"
  value={assigns.name}
  phx-change="name_changed"
/>
```

```elixir
def handle_event("name_changed", %{value: name}, assigns),
  do: {:noreply, %{assigns | name: name}}
```

Stable string IDs are required for stateful native controls. They preserve
focus, editing state, popup state, and selection across snapshots. Duplicate
IDs are rejected before a snapshot reaches a display.

Continue with [Components and styling](components-and-styling.html),
[Overlays and menus](overlays-and-menus.html), and
[Sessions, runtimes, and displays](sessions-and-displays.html).
