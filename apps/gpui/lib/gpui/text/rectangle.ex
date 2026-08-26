defmodule GPUI.Text.Rectangle do
  @moduledoc "Window-relative native pixel rectangle for laid-out text."

  @enforce_keys [:x, :y, :width, :height]
  defstruct [:x, :y, :width, :height]

  @type t :: %__MODULE__{x: float(), y: float(), width: float(), height: float()}

  @doc "Decodes a protocol rectangle map into a typed rectangle value."
  @spec from_event(map()) :: t()
  def from_event(value) when is_map(value), do: struct!(__MODULE__, value)
end
