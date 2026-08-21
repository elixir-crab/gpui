GPUITest.Examples.load!(:elixir_workbench)

defmodule GPUI.Native.ElixirWorkbenchLogSourceE2ETest do
  use GPUI.Test, desktop: true

  alias Examples.ElixirWorkbench.LogApp, as: App

  @moduletag :e2e

  test "desktop renders a bounded distant log slice", %{desktop: desktop} do
    runtime = start_runtime!(desktop, app: App, args: %{events: events(5_000)})
    window = Desktop.window!(desktop, "Runtime Log Stream")
    Desktop.await_frame!(desktop, runtime, 1, window)
    assert %{events: events} = root_assigns(runtime)
    assert [first | _events] = events
    assert is_map(first)
    assert Enum.count_until(events, 65) <= 64
    assert Process.alive?(runtime)
  end

  defp events(count) do
    Enum.map(1..count, fn sequence ->
      %{
        timestamp: "12:00:00.000",
        level: level(sequence),
        source: "worker-#{rem(sequence, 8)}",
        message: "processed event #{sequence}",
        metadata: %{partition: rem(sequence, 16)}
      }
    end)
  end

  defp level(sequence) do
    case rem(sequence, 4) do
      0 -> :debug
      1 -> :info
      2 -> :warning
      3 -> :error
    end
  end

  defp root_assigns(runtime) do
    runtime
    |> GPUI.Runtime.snapshot()
    |> Map.fetch!(:windows)
    |> hd()
    |> get_in([:root, :assigns])
  end
end
