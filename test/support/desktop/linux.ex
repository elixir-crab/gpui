defmodule GPUITest.Desktop.Linux do
  @moduledoc false

  import ExUnit.Assertions

  @project_root Mix.Project.project_file() |> Path.dirname()
  @driver_manifest Path.join(
                     @project_root,
                     "test/support/desktop/drivers/linux/Cargo.toml"
                   )

  def window_id!(title) do
    case System.cmd(
           "xdotool",
           ["search", "--sync", "--onlyvisible", "--name", "^#{title}$"],
           stderr_to_stdout: true
         ) do
      {output, 0} -> output |> String.split() |> List.first()
      {output, status} -> flunk("window lookup failed (#{status}): #{output}")
    end
  end

  def request_frame!(window_id, x, y),
    do: command!(["mousemove", "--sync", "--window", window_id, to_string(x), to_string(y)])

  def click!(window_id, x, y) do
    request_frame!(window_id, x, y)
    command!(["click", "1"])
  end

  def type!(window_id, text),
    do: command!(["type", "--window", window_id, "--delay", "30", text])

  def key!(window_id, key), do: command!(["key", "--window", window_id, key])
  def close_window!(window_id), do: driver!("close-window", [window_id])
  def capture!(window_id, path), do: driver!("capture-window", [window_id, path])

  def repeat_click!(window_id, x, y, count) do
    request_frame!(window_id, x, y)
    command!(["click", "--repeat", to_string(count), "1"])
  end

  def drag!(window_id, from_x, from_y, to_x, to_y) do
    request_frame!(window_id, from_x, from_y)
    command!(["mousedown", "1"])
    request_frame!(window_id, to_x, to_y)
    command!(["mouseup", "1"])
  end

  def resize!(window_id, width, height),
    do: command!(["windowsize", window_id, to_string(width), to_string(height)])

  def capabilities do
    MapSet.new([:window_system, :synthetic_input, :window_capture, :native_close, :window_drag])
  end

  defp command!(arguments) do
    case System.cmd("xdotool", arguments, stderr_to_stdout: true) do
      {output, 0} ->
        String.trim(output)

      {output, status} ->
        flunk("xdotool #{Enum.join(arguments, " ")} failed (#{status}): #{output}")
    end
  end

  defp driver!(command, arguments) do
    args = ["run", "--quiet", "--manifest-path", @driver_manifest, "--", command | arguments]

    case System.cmd("cargo", args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> flunk("#{command} failed (#{status}): #{output}")
    end
  end
end
