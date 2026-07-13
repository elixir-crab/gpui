defmodule GPUITest.E2E.Desktop do
  @moduledoc false

  import ExUnit.Assertions

  @eventually_timeout 3_000
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
    eventually(fn ->
      case System.cmd("xdotool", ["search", "--onlyvisible", "--name", "^#{title}$"],
             stderr_to_stdout: true
           ) do
        {output, 0} -> output |> String.split() |> List.first()
        {_output, _status} -> nil
      end
    end)
  end

  def click!(window_id, x, y) do
    command!(["mousemove", "--sync", "--window", window_id, to_string(x), to_string(y)])
    command!(["click", "1"])
  end

  def type!(window_id, text),
    do: command!(["type", "--window", window_id, "--delay", "30", text])

  def key!(window_id, key), do: command!(["key", "--window", window_id, key])

  def close_window!(window_id) do
    args = [
      "run",
      "--quiet",
      "--manifest-path",
      @driver_manifest,
      "--",
      "close-window",
      window_id
    ]

    case System.cmd("cargo", args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> flunk("sending WM_DELETE_WINDOW failed (#{status}): #{output}")
    end
  end

  def eventually(fun, timeout \\ @eventually_timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    eventually(fun, deadline, nil)
  end

  def stop_process(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp eventually(fun, deadline, last_error) do
    case evaluate(fun) do
      {:ok, value} when value not in [false, nil] -> value
      {:ok, _value} -> retry(fun, deadline, last_error)
      {:error, error} -> retry(fun, deadline, error)
    end
  end

  defp evaluate(fun) do
    {:ok, fun.()}
  rescue
    error in [ExUnit.AssertionError, MatchError] -> {:error, error}
  catch
    :exit, reason -> {:error, reason}
  end

  defp retry(fun, deadline, last_error) do
    if System.monotonic_time(:millisecond) >= deadline do
      flunk("condition was not satisfied before timeout; last error: #{inspect(last_error)}")
    end

    Process.sleep(20)
    eventually(fun, deadline, last_error)
  end
end
