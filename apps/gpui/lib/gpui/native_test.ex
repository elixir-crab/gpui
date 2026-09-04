defmodule GPUI.Native.Test do
  @moduledoc "Generated low-level façade for deterministic native-test NIF commands.\n\n`GPUI.Test` owns the public ExUnit workflow. This module keeps the\ngenerated boundary scoped and is intended for GPUI's supervised native\ntest adapter rather than direct application use.\n"
  def start(width, height) do
    GPUI.Native.Backend.native_test_start(width, height)
  end

  def render(id, tree) do
    GPUI.Native.Backend.native_test_render(id, tree)
  end

  def focus(id, target) do
    GPUI.Native.Backend.native_test_focus(id, target)
  end

  def click(id, target) do
    GPUI.Native.Backend.native_test_click(id, target)
  end

  def click_at(id, x, y) do
    GPUI.Native.Backend.native_test_click_at(id, x, y)
  end

  def scroll(id, target, delta_x, delta_y) do
    GPUI.Native.Backend.native_test_scroll(id, target, delta_x, delta_y)
  end

  def input(id, text) do
    GPUI.Native.Backend.native_test_input(id, text)
  end

  def resize(id, width, height) do
    GPUI.Native.Backend.native_test_resize(id, width, height)
  end

  def bounds(id, target) do
    GPUI.Native.Backend.native_test_bounds(id, target)
  end

  def settle(id) do
    GPUI.Native.Backend.native_test_idle(id)
  end

  def advance(id, milliseconds) do
    GPUI.Native.Backend.native_test_advance(id, milliseconds)
  end

  def press(id, key) do
    GPUI.Native.Backend.native_test_key(id, key)
  end

  def events(id) do
    GPUI.Native.Backend.native_test_events(id)
  end

  def stop(id) do
    GPUI.Native.Backend.native_test_stop(id)
  end
end
