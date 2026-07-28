defmodule GPUI.Event do
  @moduledoc """
  Normalized UI event delivered from a display into `GPUI.Session`.
  """

  defstruct [:type, :window_id, :event, :value, attrs: %{}]

  @type type ::
          :click
          | :command
          | :change
          | :select
          | :release
          | :search
          | :submit
          | :range
          | :transaction
          | :selection
          | :viewport
          | :geometry
          | :keydown
          | :keyup
          | :window_closed
          | atom()
  @type t :: %__MODULE__{
          type: type(),
          window_id: pos_integer() | nil,
          event: String.t() | nil,
          value: term(),
          attrs: map()
        }

  @spec normalize(t() | map() | keyword()) :: map()
  def normalize(%__MODULE__{} = event), do: to_map(event)
  def normalize(event) when is_list(event), do: event |> Map.new() |> normalize()

  def normalize(%{type: _type} = event), do: event

  def normalize(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  def normalize(event) when is_map(event), do: event

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = event) do
    event
    |> Map.from_struct()
    |> Map.delete(:attrs)
    |> Map.merge(event.attrs)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
