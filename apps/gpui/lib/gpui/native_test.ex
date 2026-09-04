defmodule GPUI.Native.Test do
  @moduledoc "Generated low-level façade for deterministic native-test NIF commands.\n\n`GPUI.Test` owns the public ExUnit workflow. This module keeps the\ngenerated boundary scoped and is intended for GPUI's supervised native\ntest adapter rather than direct application use.\n"
  (
    @doc "Starts a deterministic native-test session."
    def start(width, height) do
      GPUI.Native.Backend.native_test_start(width, height)
    end
  )

  (
    @doc "Renders a tree into a deterministic native-test session."
    def render(id, tree) do
      GPUI.Native.Backend.native_test_render(id, tree)
    end
  )

  (
    @doc "Focuses a target in a deterministic native-test session."
    def focus(id, target) do
      GPUI.Native.Backend.native_test_focus(id, target)
    end
  )

  (
    @doc "Clicks a target in a deterministic native-test session."
    def click(id, target) do
      GPUI.Native.Backend.native_test_click(id, target)
    end
  )

  (
    @doc "Clicks coordinates in a deterministic native-test session."
    def click_at(id, x, y) do
      GPUI.Native.Backend.native_test_click_at(id, x, y)
    end
  )

  (
    @doc "Scrolls a target in a deterministic native-test session."
    def scroll(id, target, delta_x, delta_y) do
      GPUI.Native.Backend.native_test_scroll(id, target, delta_x, delta_y)
    end
  )

  (
    @doc "Types text into a deterministic native-test session."
    def input(id, text) do
      GPUI.Native.Backend.native_test_input(id, text)
    end
  )

  (
    @doc "Resizes a deterministic native-test session."
    def resize(id, width, height) do
      GPUI.Native.Backend.native_test_resize(id, width, height)
    end
  )

  (
    @doc "Returns target bounds from a deterministic native-test session."
    def bounds(id, target) do
      GPUI.Native.Backend.native_test_bounds(id, target)
    end
  )

  (
    @doc "Runs a deterministic native-test session until idle."
    def settle(id) do
      GPUI.Native.Backend.native_test_idle(id)
    end
  )

  (
    @doc "Advances a deterministic native-test session's clock."
    def advance(id, milliseconds) do
      GPUI.Native.Backend.native_test_advance(id, milliseconds)
    end
  )

  (
    @doc "Presses a key in a deterministic native-test session."
    def press(id, key) do
      GPUI.Native.Backend.native_test_key(id, key)
    end
  )

  (
    @doc "Drains events from a deterministic native-test session."
    def events(id) do
      GPUI.Native.Backend.native_test_events(id)
    end
  )

  (
    @doc "Stops a deterministic native-test session."
    def stop(id) do
      GPUI.Native.Backend.native_test_stop(id)
    end
  )
end
