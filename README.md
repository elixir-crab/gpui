# GPUI

Elixir/OTP bindings and a HEEx-style UI layer for [GPUI](https://www.gpui.rs),
with native controls provided by
[`gpui-component`](https://github.com/longbridge/gpui-component).

GPUI applications keep state and event handling in Elixir while a Rust display
owns native windows, rendering, focus, and platform input. The same application
session can be presented locally or through the remote display protocol.

> GPUI is currently private and unpublished. Version `0.1.x` is under active
> development and only x86-64 GNU/Linux has completed release validation.

## Installation

After publication, add `gpui` to your dependencies:

```elixir
def deps do
  [{:gpui, "~> 0.1"}]
end
```

Precompiled NIFs are planned for validated targets. Source builds require Rust
and the platform GPUI development libraries. See
[Native builds and deployment](guides/deployment/native-builds.md).

## Quick start

```elixir
defmodule CounterView do
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

defmodule CounterApp do
  use GPUI.Application

  @impl GPUI.Application
  def mount(_args) do
    {:ok,
     [
       window "Counter" do
         size(320, 240)
         root(CounterView, count: 0)
       end
     ]}
  end
end

children = [{CounterApp, poll_interval: 16}]
Supervisor.start_link(children, strategy: :one_for_one)
```

See [Getting started](guides/introduction/getting-started.md) for installation,
native prerequisites, supervision, controlled components, and event handling.

## What GPUI provides

- Renderer-independent application sessions and typed snapshots.
- A process-global native GPUI loop that safely owns multiple runtimes and windows.
- HEEx-style templates with aliases, named slots, and schema-backed styling.
- Controlled native form controls and overlays backed directly by `gpui-component`.
- Local native and remote TCP/SSL displays.
- Public deterministic ExUnit helpers that do not require a native library or display.
- RustQ-generated Rustler contracts, decoders, element dispatch, and registry glue.
- Native Xvfb/Lavapipe interaction coverage and source-build fallback.

## Documentation

- [Getting started](guides/introduction/getting-started.md)
- [Sessions, runtimes, and displays](guides/architecture/sessions-and-displays.md)
- [Components and styling](guides/ui/components-and-styling.md)
- [Overlays and menus](guides/ui/overlays-and-menus.md)
- [Remote displays](guides/remote/remote-displays.md)
- [Testing GPUI applications](guides/testing/testing.md)
- [Native builds and deployment](guides/deployment/native-builds.md)
- [API reference](https://hexdocs.pm/gpui/api-reference.html)

## Development

```bash
mix deps.get
mix ci
mix test_e2e
RUST_FONTCONFIG_DLOPEN=1 mix gpui.release.check
```

`mix ci` covers Elixir, generated Rust freshness, Cargo feature matrices,
Clippy, native unit tests, Dialyzer, Credo, duplication, and architecture
checks. `mix test_e2e` runs real native windows under Xvfb with Lavapipe.

## License

MIT
