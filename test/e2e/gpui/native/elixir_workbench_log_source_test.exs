GPUITest.Examples.load!(:elixir_workbench)

defmodule GPUI.Native.ElixirWorkbenchLogSourceE2ETest do
  use ExUnit.Case, async: false

  alias Examples.ElixirWorkbench.LogApp, as: App
  alias GPUITest.Desktop

  @moduletag :e2e

  test "renders bounded log slices and supports native selection, navigation, pause, and clear" do
    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: App,
        args: %{events: events(5_000)}
      )

    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    window_id = Desktop.window_id!("Runtime Log Stream")
    Desktop.await_frame!(runtime, 1, window_id)

    snapshot = GPUI.Runtime.snapshot(runtime)
    assigns = snapshot.windows |> hd() |> get_in([:root, :assigns])
    assert assigns.retained_count == 5_000
    assert assigns.total_count == 5_000
    refute Map.has_key?(assigns, :all_events)

    loaded = snapshot |> GPUI.Test.tree() |> GPUI.Test.all(type: :ui_code_line)
    assert Enum.count_until(loaded, 49) <= 48
    assert Enum.any?(loaded, &match?(%{attrs: %{id: "event-5000"}}, &1))

    Desktop.click!(window_id, 240, 220)
    selected = await_selection(runtime)
    assert String.starts_with?(selected, "event-")
    Desktop.await_frame!(runtime, 1, window_id)

    Desktop.key!(window_id, "Up")
    previous = await_selection(runtime)
    assert event_number(previous) == event_number(selected) - 1

    Desktop.click!(window_id, 1_030, 50)
    await_click(runtime, "toggle_pause")
    assert root_assigns(runtime).paused

    Desktop.click!(window_id, 1_145, 50)
    await_click(runtime, "clear_events")
    Desktop.await_frame!(runtime, 1, window_id)

    assert %{retained_count: 0, total_count: 0, events: []} = root_assigns(runtime)
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

  defp await_selection(runtime) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        case Enum.find_value(events, fn
               %{event: "event_selected", value: selected} -> selected
               _event -> nil
             end) do
          nil -> await_selection(runtime)
          selected -> selected
        end
    after
      5_000 -> flunk("log stream did not emit a native selection")
    end
  end

  defp await_click(runtime, event_name) do
    receive do
      {:gpui, ^runtime, %GPUI.Runtime.Update{events: events}} ->
        if Enum.any?(events, &match?(%{event: ^event_name}, &1)) do
          :ok
        else
          await_click(runtime, event_name)
        end
    after
      5_000 -> flunk("log stream did not emit #{event_name}")
    end
  end

  defp root_assigns(runtime) do
    runtime
    |> GPUI.Runtime.snapshot()
    |> Map.fetch!(:windows)
    |> hd()
    |> get_in([:root, :assigns])
  end

  defp event_number("event-" <> number), do: String.to_integer(number)
end
