defmodule GPUI.Transfer.Event do
  @moduledoc """
  A bounded renderer-independent drag/drop event fact.

  `position` is expressed in the closed `:window_native_pixels` coordinate
  space. External paths in `payload` always name resources on the machine
  running the display; this value does not read or interpret them.
  """

  alias GPUI.Transfer.Payload

  @types [:drag_enter, :drag_move, :drag_leave, :drop]
  @payload_types [:drag_enter, :drop]
  @coordinate_space :window_native_pixels
  @wire_coordinate_space "window_native_pixels"
  @max_target_id_bytes 128

  @enforce_keys [:session_id, :target_id, :position, :coordinate_space, :payload]
  defstruct [:session_id, :target_id, :position, :coordinate_space, :payload]

  @type type :: :drag_enter | :drag_move | :drag_leave | :drop
  @type coordinate_space :: :window_native_pixels
  @type position :: {number(), number()}
  @type t :: %__MODULE__{
          session_id: pos_integer(),
          target_id: String.t(),
          position: position(),
          coordinate_space: coordinate_space(),
          payload: Payload.t() | nil
        }

  @doc "Normalizes a native wire map or validates an existing transfer event value."
  @spec normalize(type(), t() | map()) :: {:ok, t()} | {:error, term()}
  def normalize(type, %__MODULE__{} = value) when type in @types do
    validate(type, value)
  rescue
    error in ArgumentError -> {:error, {:invalid_transfer_event, Exception.message(error)}}
  end

  def normalize(type, value) when type in @types and is_map(value) do
    with {:ok, position} <- normalize_position(value),
         {:ok, coordinate_space} <- normalize_coordinate_space(Map.get(value, :coordinate_space)),
         {:ok, payload} <- normalize_payload(Map.get(value, :payload)) do
      validate(type, %__MODULE__{
        session_id: Map.get(value, :session_id),
        target_id: Map.get(value, :target_id),
        position: position,
        coordinate_space: coordinate_space,
        payload: payload
      })
    end
  rescue
    error in ArgumentError -> {:error, {:invalid_transfer_event, Exception.message(error)}}
  end

  def normalize(type, _value) when type in @types,
    do: {:error, {:invalid_transfer_event, :value_must_be_a_map}}

  @doc "Normalizes a transfer event value or raises `ArgumentError`."
  @spec normalize!(type(), t() | map()) :: t()
  def normalize!(type, value) do
    case normalize(type, value) do
      {:ok, normalized} -> normalized
      {:error, reason} -> raise ArgumentError, "invalid transfer event: #{inspect(reason)}"
    end
  end

  @doc "Returns whether a term is a supported drag/drop event type."
  @spec type?(term()) :: boolean()
  def type?(type), do: type in @types

  @doc "Converts a canonical transfer event into its serializable native/remote wire map."
  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = value) do
    {x, y} = value.position

    %{
      session_id: value.session_id,
      target_id: value.target_id,
      x: x,
      y: y,
      coordinate_space: @wire_coordinate_space,
      payload: if(value.payload, do: Payload.to_payload(value.payload))
    }
  end

  defp validate(type, value) do
    with :ok <- validate_session_id(value.session_id),
         :ok <- validate_target_id(value.target_id),
         :ok <- validate_position(value.position),
         :ok <- validate_coordinate_space(value.coordinate_space),
         :ok <- validate_canonical_payload(value.payload),
         :ok <- validate_payload_presence(type, value.payload) do
      {:ok, value}
    end
  end

  defp normalize_position(%{position: {x, y}}), do: {:ok, {x, y}}
  defp normalize_position(value), do: {:ok, {Map.get(value, :x), Map.get(value, :y)}}

  defp normalize_coordinate_space(@coordinate_space), do: {:ok, @coordinate_space}
  defp normalize_coordinate_space(@wire_coordinate_space), do: {:ok, @coordinate_space}

  defp normalize_coordinate_space(_coordinate_space),
    do: {:error, {:invalid_transfer_event, :coordinate_space}}

  defp validate_session_id(session_id) when is_integer(session_id) and session_id > 0, do: :ok
  defp validate_session_id(_session_id), do: {:error, {:invalid_transfer_event, :session_id}}

  defp validate_target_id(target_id)
       when is_binary(target_id) and target_id != "" and
              byte_size(target_id) <= @max_target_id_bytes do
    if String.valid?(target_id), do: :ok, else: {:error, {:invalid_transfer_event, :target_id}}
  end

  defp validate_target_id(_target_id), do: {:error, {:invalid_transfer_event, :target_id}}

  defp validate_position({x, y}) do
    with :ok <- validate_coordinate(x, :x), do: validate_coordinate(y, :y)
  end

  defp validate_position(_position), do: {:error, {:invalid_transfer_event, :position}}

  defp validate_coordinate(value, _name) when is_integer(value), do: :ok

  defp validate_coordinate(value, name) when is_float(value) do
    if finite_float?(value), do: :ok, else: {:error, {:invalid_transfer_event, name}}
  end

  defp validate_coordinate(_value, name), do: {:error, {:invalid_transfer_event, name}}

  defp finite_float?(value) do
    value |> :erlang.float_to_binary() |> then(&(&1 not in ["nan", "inf", "-inf"]))
  end

  defp validate_coordinate_space(@coordinate_space), do: :ok

  defp validate_coordinate_space(_coordinate_space),
    do: {:error, {:invalid_transfer_event, :coordinate_space}}

  defp normalize_payload(nil), do: {:ok, nil}
  defp normalize_payload(%Payload{} = payload), do: {:ok, payload}
  defp normalize_payload(payload) when is_map(payload), do: {:ok, Payload.new(payload)}
  defp normalize_payload(_payload), do: {:error, {:invalid_transfer_event, :payload}}

  defp validate_canonical_payload(nil), do: :ok
  defp validate_canonical_payload(%Payload{} = payload), do: Payload.validate!(payload)
  defp validate_canonical_payload(_payload), do: {:error, {:invalid_transfer_event, :payload}}

  defp validate_payload_presence(type, %Payload{}) when type in @payload_types, do: :ok
  defp validate_payload_presence(type, nil) when type not in @payload_types, do: :ok

  defp validate_payload_presence(_type, _payload),
    do: {:error, {:invalid_transfer_event, :payload_presence}}
end
