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
    do: command!(["mousemove", "--window", window_id, to_string(x), to_string(y)])

  def click!(window_id, x, y) do
    request_frame!(window_id, x, y)
    command!(["click", "1"])
  end

  def scroll!(window_id, x, y, delta_x, delta_y) do
    request_frame!(window_id, x, y)
    wheel!(delta_y, 4, 5)
    wheel!(delta_x, 6, 7)
  end

  def type!(window_id, text),
    do: command!(["type", "--window", window_id, "--delay", "30", text])

  def key!(window_id, key), do: command!(["key", "--window", window_id, linux_key(key)])
  def close_window!(window_id), do: driver!("close-window", [window_id])
  def capture!(window_id, path), do: driver!("capture-window", [window_id, path])

  def window_info!(window_id) do
    output = command!(["getwindowgeometry", "--shell", window_id])

    values =
      output
      |> String.split("\n", trim: true)
      |> Map.new(fn line ->
        [key, value] = String.split(line, "=", parts: 2)
        {String.downcase(key), String.to_integer(value)}
      end)

    %{
      id: window_id,
      frame: %{x: values["x"], y: values["y"], width: values["width"], height: values["height"]}
    }
  end

  def repeat_click!(window_id, x, y, count) do
    request_frame!(window_id, x, y)
    command!(["click", "--repeat", to_string(count), "1"])
  end

  def drag!(window_id, from_x, from_y, to_x, to_y) do
    request_frame!(window_id, from_x, from_y)
    command!(["mousedown", "1"])
    Process.sleep(20)

    1..10
    |> Enum.each(fn step ->
      previous_step = step - 1

      command!([
        "mousemove_relative",
        "--sync",
        "--",
        to_string(div((to_x - from_x) * step, 10) - div((to_x - from_x) * previous_step, 10)),
        to_string(div((to_y - from_y) * step, 10) - div((to_y - from_y) * previous_step, 10))
      ])

      Process.sleep(10)
    end)

    command!(["mouseup", "1"])
  end

  def resize!(window_id, width, height),
    do: command!(["windowsize", window_id, to_string(width), to_string(height)])

  def capabilities do
    MapSet.new([
      :window_system,
      :synthetic_input,
      :scroll_wheel,
      :window_capture,
      :native_close
    ])
  end

  defp linux_key(key), do: String.replace(key, "primary+", "ctrl+")

  defp wheel!(delta, positive_delta_button, negative_delta_button) when is_number(delta) do
    count = delta |> abs() |> Kernel./(40) |> Float.ceil() |> trunc()

    if count > 0 do
      button = if delta > 0, do: positive_delta_button, else: negative_delta_button
      command!(["click", "--repeat", to_string(count), to_string(button)])
    end
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
