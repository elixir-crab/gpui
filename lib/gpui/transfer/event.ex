defmodule GPUI.Transfer.Event do
  @moduledoc """
  Validation for bounded drag/drop event facts.

  Coordinates use native display-window pixels. External paths always name
  resources on the machine running the display.
  """

  alias GPUI.Transfer.Payload

  @types [:drag_enter, :drag_move, :drag_leave, :drop]
  @payload_types [:drag_enter, :drop]
  @coordinate_space "window_native_pixels"
  @max_target_id_bytes 128

  @type type :: :drag_enter | :drag_move | :drag_leave | :drop
  @type value :: %{
          required(:session_id) => pos_integer(),
          required(:target_id) => String.t(),
          required(:x) => number(),
          required(:y) => number(),
          required(:coordinate_space) => String.t(),
          required(:payload) => Payload.t() | nil
        }

  @spec normalize(type(), map()) :: {:ok, value()} | {:error, term()}
  def normalize(type, value) when type in @types and is_map(value) do
    with :ok <- validate_session_id(Map.get(value, :session_id)),
         :ok <- validate_target_id(Map.get(value, :target_id)),
         :ok <- validate_coordinate(Map.get(value, :x), :x),
         :ok <- validate_coordinate(Map.get(value, :y), :y),
         :ok <- validate_coordinate_space(Map.get(value, :coordinate_space)),
         {:ok, payload} <- normalize_payload(Map.get(value, :payload)),
         :ok <- validate_payload_presence(type, payload) do
      {:ok,
       %{
         session_id: value.session_id,
         target_id: value.target_id,
         x: value.x,
         y: value.y,
         coordinate_space: @coordinate_space,
         payload: payload
       }}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, {:invalid_transfer_event, Exception.message(error)}}
  end

  def normalize(type, _value) when type in @types,
    do: {:error, {:invalid_transfer_event, :value_must_be_a_map}}

  @spec normalize!(type(), map()) :: value()
  def normalize!(type, value) do
    case normalize(type, value) do
      {:ok, normalized} -> normalized
      {:error, reason} -> raise ArgumentError, "invalid transfer event: #{inspect(reason)}"
    end
  end

  @spec type?(term()) :: boolean()
  def type?(type), do: type in @types

  defp validate_session_id(session_id) when is_integer(session_id) and session_id > 0, do: :ok
  defp validate_session_id(_session_id), do: {:error, {:invalid_transfer_event, :session_id}}

  defp validate_target_id(target_id)
       when is_binary(target_id) and target_id != "" and
              byte_size(target_id) <= @max_target_id_bytes,
       do: :ok

  defp validate_target_id(_target_id), do: {:error, {:invalid_transfer_event, :target_id}}

  defp validate_coordinate(value, _name) when is_integer(value), do: :ok

  defp validate_coordinate(value, name) when is_float(value) do
    if finite_float?(value), do: :ok, else: {:error, {:invalid_transfer_event, name}}
  end

  defp validate_coordinate(_value, name), do: {:error, {:invalid_transfer_event, name}}

  defp finite_float?(value) do
    case :erlang.float_to_binary(value) do
      "nan" -> false
      "inf" -> false
      "-inf" -> false
      _finite -> true
    end
  end

  defp validate_coordinate_space(@coordinate_space), do: :ok

  defp validate_coordinate_space(_coordinate_space),
    do: {:error, {:invalid_transfer_event, :coordinate_space}}

  defp normalize_payload(nil), do: {:ok, nil}

  defp normalize_payload(%Payload{} = payload) do
    Payload.validate!(payload)
    {:ok, payload}
  end

  defp normalize_payload(payload) when is_map(payload), do: {:ok, Payload.new(payload)}
  defp normalize_payload(_payload), do: {:error, {:invalid_transfer_event, :payload}}

  defp validate_payload_presence(type, %Payload{}) when type in @payload_types, do: :ok
  defp validate_payload_presence(type, nil) when type not in @payload_types, do: :ok

  defp validate_payload_presence(_type, _payload),
    do: {:error, {:invalid_transfer_event, :payload_presence}}
end
