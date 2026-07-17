defmodule GPUITest.E2E.Desktop do
  @moduledoc false

  import ExUnit.Assertions

  @update_timeout 3_000
  @driver_manifest Path.expand("../e2e_driver/Cargo.toml", __DIR__)

  def command!(arguments) do
    case System.cmd("xdotool", arguments, stderr_to_stdout: true) do
      {output, 0} ->
        String.trim(output)

      {output, status} ->
        flunk("xdotool #{Enum.join(arguments, " ")} failed (#{status}): #{output}")
    end
  end

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

  def request_frame!(window_id, x \\ 1, y \\ 1),
    do: command!(["mousemove", "--sync", "--window", window_id, to_string(x), to_string(y)])

  def await_frame!(source, window_id, native_window_id) do
    coordinate = Process.get(:gpui_frame_coordinate, 1)
    Process.put(:gpui_frame_coordinate, 3 - coordinate)

    command!([
      "mousemove",
      "--window",
      native_window_id,
      to_string(coordinate),
      to_string(coordinate)
    ])

    assert :ok = GPUI.Display.call_await_frame(source, window_id, @update_timeout)
  end

  def click!(window_id, x, y) do
    request_frame!(window_id, x, y)
    command!(["click", "1"])
  end

  def type!(window_id, text),
    do: command!(["type", "--window", window_id, "--delay", "30", text])

  def key!(window_id, key), do: command!(["key", "--window", window_id, key])

  def refute_update!(source, action, timeout \\ 150) do
    flush_updates(source)
    action.()
    refute_receive {:gpui, ^source, %GPUI.Runtime.Update{}}, timeout
  end

  def close_window!(window_id), do: driver!("close-window", [window_id])

  def capture!(window_id, path), do: driver!("capture-window", [window_id, path])

  defp driver!(command, arguments) do
    args = [
      "run",
      "--quiet",
      "--manifest-path",
      @driver_manifest,
      "--",
      command | arguments
    ]

    case System.cmd("cargo", args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> flunk("#{command} failed (#{status}): #{output}")
    end
  end

  def eventually(fun, timeout \\ @update_timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    await_update(fun, deadline, nil)
  end

  def stop_process(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp await_update(fun, deadline, last_error) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:gpui, _source, %GPUI.Runtime.Update{}} ->
        case evaluate(fun) do
          {:ok, value} when value not in [false, nil] -> value
          {:ok, _value} -> await_update(fun, deadline, last_error)
          {:error, error} -> await_update(fun, deadline, error)
        end
    after
      remaining ->
        flunk("update was not received before timeout; last error: #{inspect(last_error)}")
    end
  end

  defp flush_updates(source) do
    receive do
      {:gpui, ^source, %GPUI.Runtime.Update{}} -> flush_updates(source)
    after
      0 -> :ok
    end
  end

  defp evaluate(fun) do
    {:ok, fun.()}
  rescue
    error in [ExUnit.AssertionError, MatchError] -> {:error, error}
  catch
    :exit, reason -> {:error, reason}
  end
end
