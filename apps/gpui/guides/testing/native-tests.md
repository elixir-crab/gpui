# Deterministic native tests

Use deterministic native tests when behavior depends on GPUI layout, focus, hit
testing, keyboard dispatch, or real `gpui-component` mechanics but not on a
desktop window or operating-system integration.

```elixir
defmodule MyApp.SettingsNativeTest do
  use GPUI.Test, native: [size: {320, 160}]

  test "radio navigation skips disabled choices", %{ui: ui} do
    render(ui, SettingsView, plan: "free", notifications: false)

    focus(ui, "plan")
    press(ui, :arrow_right)

    assert_receive {:gpui, ^ui,
                    {:event,
                     %{type: :change, event: "plan_changed", value: "team"}}}

    # Controlled state remains authoritative in Elixir.
    render(ui, SettingsView, plan: "team", notifications: false)
  end
end
```

`use GPUI.Test, native: ...` marks the module `:native`, requires synchronous
ExUnit execution, starts a supervised UI for each test, and supplies its opaque
handle as `%{ui: ui}`.

## Interaction vocabulary

The imported command set is deliberately small:

```elixir
render(ui, SettingsView, plan: "free")
focus(ui, "plan")
press(ui, :space)
click(ui, "notifications")
click(ui, {24, 48})
scroll(ui, "records", delta: {0, -240})
type(ui, "Ada")
resize(ui, {800, 600})
advance(ui, 250)
assert %{width: width, height: height} = bounds(ui, "notifications")
settle(ui)
```

Stable targets come from declarative `id` attributes. `click/2` targets the
center of rendered bounds or an explicit `{x, y}` logical point. `bounds/2`
returns `%{x:, y:, width:, height:}` in logical pixels. `scroll/3` dispatches a
bounded logical-pixel wheel delta at the target center. `type/2` dispatches text
input to the focused control, while `resize/2` changes the deterministic
viewport.

`advance/2` moves GPUI's test clock by a bounded number of milliseconds and
settles pending work. `press/2` accepts semantic keys such as `:arrow_left`,
`:arrow_right`, `:arrow_up`, `:arrow_down`, `:space`, `:enter`, `:escape`, and
`:tab`, or a GPUI keystroke string.

## Assert ordinary events

Native events use the ExUnit mailbox rather than a custom assertion language:

```elixir
click(ui, "notifications")

assert_receive {:gpui, ^ui,
                {:event,
                 %{type: :change,
                   event: "notifications_changed",
                   value: true}}}
```

The Elixir test owns fixtures, assigns, actions, controlled rerenders, and
assertions. Rust remains a generic interpreter around GPUI's `TestAppContext`;
component-specific fixtures and assertions do not belong in the native harness.

## Run native tests

```bash
mix gpui.test.native
mix gpui.test.native test/gpui/test/native/controls_test.exs
mix gpui.test.native test/gpui/my_settings_native_test.exs
```

The task selects `MIX_TARGET=native_test`, leaving ordinary `MIX_ENV=test`
renderer-independent. RustQ generates the NIF exports and Elixir stubs for the
closed native-test command boundary.

To verify ordinary, deterministic-native, and desktop artifact isolation without
cleaning build directories or deleting NIFs, run:

```bash
mix gpui.test.mode_switch
```

## What this layer proves

Deterministic native tests own facts such as:

- stable GPUI layout bounds and hit testing;
- pointer activation and wheel delivery into components;
- native focus and keyboard navigation;
- disabled and loading interaction suppression;
- controlled-value reconciliation after native edits;
- source-backed range requests and collection transitions;
- dialog top-layer mechanics through the real `gpui_component::Root`;
- real `gpui_component::InputState` typing and submit behavior;
- bounded animation state through the deterministic GPUI clock.

The harness installs the production-like hierarchy:

```text
gpui_component::Root
└── ElixirRoot
```

This permits real dialog, input, and component mechanics without alternate
test-only product implementations.

The pinned GPUI revision includes
[zed-industries/zed#62775](https://github.com/zed-industries/zed/pull/62775), so
`TestWindow` reports `raw_window_handle::HandleError::NotSupported` instead of
panicking when a component requests an unavailable raw window or display handle.
Native content-type integration can therefore degrade cleanly in this harness.

## What remains desktop-owned

These tests do not prove operating-system facts. Keep the following in
[Desktop E2E and visual evidence](desktop-e2e.html):

- real native window creation and application-owned chrome;
- OS close requests and process-global activation;
- accessibility-adapter behavior;
- clipboard and external file transfer;
- native IME and platform content types;
- compositor output and synchronized pixels;
- real-window focus containment and restoration.

Once deterministic coverage proves a component mechanic, desktop E2E should
retain only the platform-specific smoke assertion rather than duplicating the
full interaction sequence.
