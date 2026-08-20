defmodule GPUITest.Desktop.MacOS do
  @moduledoc false

  import ExUnit.Assertions

  @project_root Mix.Project.project_file() |> Path.dirname()
  @driver Path.join(
            @project_root,
            "test/support/desktop/drivers/macos/.build/release/gpui-desktop-driver"
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

  def window_info!(window_id) do
    [
      id,
      x,
      y,
      width,
      height,
      content_x,
      content_y,
      content_width,
      content_height,
      display_id,
      display_x,
      display_y,
      display_width,
      display_height,
      scale
    ] =
      "window-info"
      |> driver!([window_id])
      |> String.split("\t")

    %{
      id: id,
      frame: rectangle(x, y, width, height),
      content_frame: rectangle(content_x, content_y, content_width, content_height),
      display: %{
        id: display_id,
        frame: rectangle(display_x, display_y, display_width, display_height),
        scale: number(scale)
      }
    }
  end

  defp rectangle(x, y, width, height),
    do: %{x: number(x), y: number(y), width: number(width), height: number(height)}

  defp number(value) do
    case Float.parse(value) do
      {number, ""} -> number
      :error -> flunk("invalid desktop driver number: #{inspect(value)}")
    end
  end

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
