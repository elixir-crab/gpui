defmodule GPUI.Remote.DisplayProtocol do
  @moduledoc """
  GPUI remote display operation contract.

  SafeRPC owns the RPC envelope, safe ETF decoding, request IDs, timeouts, and
  cancellation. This module owns only GPUI's display capability and operation
  payload shapes.
  """

  @capability :gpui_display
  @ops [:hello, :open_window, :update_window, :drain_events, :event]

  @type op :: :hello | :open_window | :update_window | :drain_events | :event
  @type message :: %{op: op(), payload: map()}

  @spec capability() :: :gpui_display
  def capability, do: @capability

  @spec ops() :: [op()]
  def ops, do: @ops

  @spec known_op?(atom()) :: boolean()
  def known_op?(op), do: op in @ops

  @spec hello(map()) :: message()
  def hello(payload \\ %{role: :runtime, capabilities: [:runtime_v1]}) when is_map(payload) do
    message(:hello, payload)
  end

  @spec open_window(map()) :: message()
  def open_window(window_payload) when is_map(window_payload) do
    message(:open_window, window_payload)
  end

  @spec update_window(pos_integer(), map() | nil) :: message()
  def update_window(window_id, tree) when is_integer(window_id) and window_id > 0 do
    message(:update_window, %{window_id: window_id, tree: tree})
  end

  @spec event(map()) :: message()
  def event(event) when is_map(event), do: message(:event, event)

  @spec drain_events() :: message()
  def drain_events, do: message(:drain_events, %{})

  defp message(op, payload), do: %{op: op, payload: payload}
end
