defmodule GPUITest.Desktop.MacOS do
  @moduledoc false

  import ExUnit.Assertions

  @driver Path.expand(
            "drivers/macos/.build/release/gpui-desktop-driver",
            __DIR__
          )

  def window_id!(title), do: driver!("find-window", [title])

  def request_frame!(window_id, x, y),
    do: driver_ok!("move", [window_id, to_string(x), to_string(y)])

  def click!(window_id, x, y),
    do: driver_ok!("click", [window_id, to_string(x), to_string(y)])

  def type!(window_id, text), do: driver_ok!("type", [window_id, text])
  def key!(window_id, key), do: driver_ok!("key", [window_id, key])
  def close_window!(window_id), do: driver_ok!("close", [window_id])
  def capture!(window_id, path), do: driver_ok!("capture", [window_id, path])

  def repeat_click!(window_id, x, y, count),
    do: driver_ok!("repeat-click", [window_id, to_string(x), to_string(y), to_string(count)])

  def drag!(window_id, from_x, from_y, to_x, to_y),
    do:
      driver_ok!("drag", [
        window_id,
        to_string(from_x),
        to_string(from_y),
        to_string(to_x),
        to_string(to_y)
      ])

  def resize!(window_id, width, height),
    do: driver_ok!("resize", [window_id, to_string(width), to_string(height)])

  def capabilities do
    capabilities = MapSet.new([:window_system])

    capabilities =
      if accessibility_trusted?(),
        do: MapSet.put(capabilities, :synthetic_input),
        else: capabilities

    capabilities =
      if accessibility_trusted?(), do: MapSet.put(capabilities, :native_close), else: capabilities

    capabilities =
      if accessibility_trusted?(), do: MapSet.put(capabilities, :window_drag), else: capabilities

    if screen_capture_allowed?(),
      do: MapSet.put(capabilities, :window_capture),
      else: capabilities
  end

  defp accessibility_trusted? do
    match?(
      {"true\n", 0},
      System.cmd("swift", ["-e", "import ApplicationServices; print(AXIsProcessTrusted())"])
    )
  end

  defp screen_capture_allowed? do
    match?(
      {"true\n", 0},
      System.cmd("swift", ["-e", "import CoreGraphics; print(CGPreflightScreenCaptureAccess())"])
    )
  end

  defp driver_ok!(command, arguments) do
    _output = driver!(command, arguments)
    :ok
  end

  defp driver!(command, arguments) do
    case System.cmd(@driver, [command | arguments], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("#{command} failed (#{status}): #{output}")
    end
  end
end
