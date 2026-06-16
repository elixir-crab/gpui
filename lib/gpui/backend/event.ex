defmodule GPUI.Backend.Event do
  @moduledoc false

  @spec normalize(map()) :: map()
  def normalize(%{type: _type} = event), do: event

  def normalize(%{window_id: _window_id, event: _event} = event),
    do: Map.put(event, :type, :click)

  def normalize(event), do: event
end
