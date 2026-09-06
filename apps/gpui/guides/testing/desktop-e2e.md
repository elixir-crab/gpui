# Desktop E2E and visual evidence

Desktop E2E runs ordinary ExUnit against real native windows. Use it only for
facts owned by the operating system, window server, accessibility adapter,
clipboard, IME, external transfer machinery, or compositor.

```elixir
defmodule MyApp.NativeWindowTest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

  @moduletag :e2e

  setup context do
    Desktop.setup(context, [])
  end
end
```

Desktop tests are serial because native windows share process-global pointer,
keyboard, focus, and desktop state.

## Run through the local orchestrator

Use the platform-aware Mix task rather than assembling environment variables by
hand:

```sh
mix gpui.test.e2e apps/gpui_native/test/e2e/gpui/native/motion_test.exs
mix gpui.test.e2e apps/gpui_native/test/e2e/gpui/native
```

On Linux, the task checks `xvfb-run`, D-Bus, and `xdotool`, then runs with Xvfb
and Lavapipe. On macOS, it checks Accessibility and Screen Recording permission,
builds the Swift desktop driver, and uses the active WindowServer and real Metal
renderer. The repository-owned E2E support is intentionally separate from the
public `GPUI.Test` API: it drives operating-system facilities and is not shipped
in the Hex packages. Both paths execute ordinary ExUnit through
`GPUITest.Desktop`; there is no separate test-runner architecture.

The source-built native artifacts for ordinary, deterministic-native, and
desktop modes are isolated. Verify the transition sequence without cleaning
build directories or deleting NIF artifacts:

```sh
mix gpui.test.mode_switch
mix gpui.test.mode_switch apps/gpui_native/test/e2e/gpui/native/form_controls_test.exs
```

The task runs ordinary ExUnit, deterministic native ExUnit, one focused desktop
E2E, ordinary ExUnit again, and deterministic native ExUnit again.

## Linux environment

Install the Linux desktop-test dependencies with:

```bash
sudo apt-get install xvfb xdotool libxkbcommon-dev libxkbcommon-x11-dev
```

The orchestrator is preferred, but the underlying ExUnit command is:

```bash
MIX_ENV=e2e RUST_FONTCONFIG_DLOPEN=1 LIBGL_ALWAYS_SOFTWARE=1 \
  GALLIUM_DRIVER=llvmpipe xvfb-run -a dbus-run-session -- \
  mix test --only e2e apps/gpui_native/test/e2e
```

Mesa Lavapipe provides software rendering and `xdotool` supplies XTest pointer
and keyboard input. The suite must not require a desktop environment or window
manager.

On a workstation with an existing display, `MIX_ENV=e2e mix test ...` can run
the ExUnit layer directly, but it remains the caller's responsibility to provide
a suitable desktop session and permissions.

## What desktop E2E owns

The suite should focus on:

- native window creation, resizing, activation, and closure;
- platform chrome and content-chrome behavior;
- real pointer, wheel, keyboard, and focus delivery;
- native IME and content-type integration;
- OS selection and clipboard behavior;
- external file drops and display-machine file pickers;
- accessibility adapters and platform actions;
- remote-native window smoke behavior;
- compositor stability and target-window capture.

Do not repeat full component-navigation or controlled-rerender suites already
covered by [Deterministic native tests](native-tests.html). A
renderer-independent injected event also does not substitute for desktop input.

## Visual capture

Behavioral E2E assertions are not pixel-level design review. Deterministic
capture definitions live under `test/visual/scenarios/`; they support the
capture tool rather than acting as independent test runners.

Capture one scenario or the complete suite with:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture \
  --scenario component_gallery \
  --theme dark \
  --output tmp/gpui-visual-dark

RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture \
  --scenario beam_control_room \
  --theme dark \
  --output tmp/beam-observatory-visual

RUST_FONTCONFIG_DLOPEN=1 mix gpui.visual.capture \
  --all \
  --output tmp/gpui-visual
```

Each scenario declares its application, initial arguments, window title,
capture names, and synchronized actions such as event dispatch, root-view
messages, and hover. The generic runner owns Xvfb startup, completed-frame
barriers, pointer movement, file naming, and cleanup. Scenarios must not sample
live state when stable screenshots are required.

Inspect images for:

- spacing and alignment;
- clipping and overflow;
- contrast and hierarchy;
- popup placement;
- focus visibility;
- theme and state variants.

The repository-only `GPUITest.Desktop.capture!/2` helper remains available to
focused E2E tests. It does not wait, inspect environment variables, or choose
output paths.

## Coverage boundaries

Visual evidence can establish what rendered pixels look like in a declared
scenario. It does not prove application state policy, and deterministic native
bounds do not prove readability. Keep each claim in the layer that can observe
it truthfully; see [Test coverage ownership](coverage-ownership.html) for the
authoritative matrix.
