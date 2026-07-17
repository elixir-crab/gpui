Code.require_file(
  "../../examples/process_explorer/support/process_explorer.exs",
  __DIR__
)

defmodule GPUI.ProcessExplorerExampleTest do
  use GPUI.Test, async: true

  alias Examples.ProcessExplorer.App
  alias Examples.ProcessExplorer.Collector

  test "filters, sorts, and inspects real process-shaped data" do
    runtime = start_gpui!(App, args: %{processes: processes()})

    assert %{processes: [_, _], selected_pid: nil, sort: "memory"} = assigns(runtime)
    assert %{type: :div} = runtime |> tree() |> find!("phx-click": "select:<0.20.0>")

    change(runtime, "filter_changed", "0.20")
    assert runtime |> tree() |> all("phx-click": "select:<0.20.0>") |> length() == 1
    assert runtime |> tree() |> all("phx-click": "select:<0.10.0>") |> length() == 0

    click(runtime, "select:<0.20.0>")
    assert %{selected_pid: "<0.20.0>"} = assigns(runtime)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(&match?(%{children: ["Elixir.Worker.loop/1"]}, &1))
  end

  test "pauses and resumes snapshots from the collector" do
    runtime = start_gpui!(App, args: %{processes: processes()})
    click(runtime, "toggle_pause")

    send_view(runtime, {:process_snapshot, [process("<0.30.0>", "new", 99)]})
    assert %{paused: true, processes: [_, _]} = assigns(runtime)

    click(runtime, "toggle_pause")
    send_view(runtime, {:process_snapshot, [process("<0.30.0>", "new", 99)]})
    assert %{paused: false, processes: [%{pid: "<0.30.0>"}]} = assigns(runtime)
  end

  test "collector reports the current BEAM process set" do
    rows = Collector.collect()

    assert rows != []
    assert Enum.any?(rows, &(&1.pid == inspect(self())))
    assert Enum.all?(rows, &is_integer(&1.memory))
  end

  defp processes do
    [
      process("<0.10.0>", "server", 2_048),
      process("<0.20.0>", "worker", 8_192)
    ]
  end

  defp process(pid, name, memory) do
    %{
      pid: pid,
      name: name,
      status: "waiting",
      message_queue_len: 0,
      memory: memory,
      reductions: memory * 2,
      current_function: "Elixir.Worker.loop/1",
      initial_call: "Elixir.Worker.start_link/1"
    }
  end
end
