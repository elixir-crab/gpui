Code.require_file(
  "../../../examples/log_trace_explorer/support/log_trace_explorer.exs",
  __DIR__
)

defmodule GPUITest.Visual.LogTraceExplorer.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  alias Examples.LogTraceExplorer.Model

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :log_trace_explorer

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.LogTraceExplorer.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme), do: %{events: events()}

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "OTP Log and Trace Explorer"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "live-tail"},
      %{
        name: "selected-error",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "event_selected", value: "event-120"}}
        ]
      },
      %{
        name: "warning-filter",
        actions: [
          {:dispatch, %{type: :change, window_id: 1, event: "level_changed", value: "warning"}},
          {:send_view_from, 1,
           fn assigns ->
             filtered = events() |> Model.prepare() |> Model.filter("", "warning")
             slice = Model.snapshot(filtered, assigns)
             {:events_slice, assigns.generation, slice, 120, 0}
           end}
        ]
      },
      %{
        name: "paused",
        actions: [{:dispatch, %{type: :click, window_id: 1, event: "toggle_pause"}}]
      },
      %{
        name: "cleared",
        actions: [{:dispatch, %{type: :click, window_id: 1, event: "clear_events"}}]
      }
    ]
  end

  defp events do
    Enum.map(1..120, fn sequence ->
      {level, source, message, metadata} = event_data(sequence)

      %{
        timestamp:
          "12:34:#{sequence |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}.#{rem(sequence * 37, 1_000) |> Integer.to_string() |> String.pad_leading(3, "0")}",
        level: level,
        source: source,
        message: message,
        metadata: metadata
      }
    end)
  end

  defp event_data(120),
    do:
      {:error, "exports", "Export failed\nconnection closed by peer",
       %{request_id: "req-120", retryable: true}}

  defp event_data(sequence) do
    case rem(sequence, 4) do
      0 -> {:debug, "cache", "Cache lookup completed", %{hit: true, key: sequence}}
      1 -> {:info, "web", "GET /api/projects completed in #{20 + sequence}ms", %{status: 200}}
      2 -> {:warning, "jobs", "Queue depth reached #{sequence}", %{queue: :exports}}
      3 -> {:info, "billing", "Invoice synchronized", %{account_id: sequence}}
    end
  end
end
