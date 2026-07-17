Code.require_file(
  "../../../examples/process_explorer/support/process_explorer.exs",
  __DIR__
)

defmodule GPUITest.Visual.ProcessExplorer.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :process_explorer

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.ProcessExplorer.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{processes: processes()}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "BEAM Process Explorer"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "processes"},
      %{
        name: "selected-process",
        actions: [
          {:dispatch,
           %{type: :change, window_id: 1, event: "process_selected", value: "<0.50.0>"}}
        ]
      }
    ]
  end

  defp processes do
    [
      process("<0.50.0>", "code_server", 2_940_000, 0, 747_605, ":code_server.loop/1"),
      process("<0.45.0>", "application_controller", 426_900, 0, 143_906, ":gen_server.loop/5"),
      process("<0.101.0>", "Elixir.Mix.State", 176_300, 0, 2_075, ":gen_server.loop/5"),
      process("<0.188.0>", "unregistered", 91_400, 2, 73_931, "Process.info/2"),
      process("<0.147.0>", "Elixir.Hex.Supervisor", 68_300, 0, 7_140, ":gen_server.loop/5"),
      process("<0.0.0>", "init", 34_400, 0, 7_234, ":init.boot_loop/2"),
      process("<0.53.0>", "file_server_2", 29_600, 1, 13_419, ":gen_server.loop/5"),
      process("<0.72.0>", "Elixir.Logger", 24_800, 0, 54_210, ":gen_server.loop/5")
    ]
  end

  defp process(pid, name, memory, mailbox, reductions, current_function) do
    %{
      pid: pid,
      name: name,
      status: "waiting",
      message_queue_len: mailbox,
      memory: memory,
      reductions: reductions,
      current_function: current_function,
      initial_call: ":erlang.apply/2"
    }
  end
end
