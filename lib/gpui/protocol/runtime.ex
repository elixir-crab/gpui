defmodule GPUI.Protocol.Runtime do
  @moduledoc """
  Versioned, transport-safe protocol for GPUI runtime/backends.

  These messages are plain Elixir terms and can cross a future remote boundary
  through ETF, distribution, TCP, or another transport. The protocol is kept
  separate from the current Rust host command protocol because it models the
  higher-level runtime contract: windows flow toward a display backend, events
  flow back toward the Elixir application runtime.
  """

  @version 1

  @type op :: :open_window | :update_window | :event | :drain_events
  @type message :: %{version: 1, op: op(), payload: map()}

  @spec version() :: 1
  def version, do: @version

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

  @spec encode(message()) :: binary()
  def encode(%{version: @version, op: op, payload: payload} = message)
      when is_atom(op) and is_map(payload) do
    GPUI.Protocol.encode(message)
  end

  @spec decode(binary()) :: message()
  def decode(payload) when is_binary(payload) do
    case GPUI.Protocol.decode(payload) do
      %{version: @version, op: op, payload: payload} = message
      when is_atom(op) and is_map(payload) ->
        message

      other ->
        raise ArgumentError, "invalid GPUI runtime protocol message: #{inspect(other)}"
    end
  end

  defp message(op, payload), do: %{version: @version, op: op, payload: payload}
end
