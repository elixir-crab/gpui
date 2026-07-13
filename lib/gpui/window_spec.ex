defmodule GPUI.WindowSpec do
  @moduledoc """
  Declarative window specification returned by the application DSL.
  """

  @type root :: {module(), map() | keyword()}
  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          title: String.t(),
          size: {pos_integer(), pos_integer()} | nil,
          root: root() | nil
        }

  @enforce_keys [:title]
  defstruct [:id, :title, :size, :root]

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{title: title, size: size, root: root} = window) do
    unless is_binary(title), do: raise(ArgumentError, "window title must be a string")

    unless valid_size?(size) do
      raise ArgumentError, "window size must contain positive integer width and height"
    end

    unless valid_root?(root) do
      raise ArgumentError, "window root must contain a module and map or keyword assigns"
    end

    if match?({_, _}, root) do
      {module, _assigns} = root

      unless Code.ensure_loaded?(module) and function_exported?(module, :render, 1) do
        raise ArgumentError, "window root #{inspect(module)} must implement render/1"
      end
    end

    window
  end

  defp valid_size?(nil), do: true
  defp valid_size?({width, height}), do: positive_integer?(width) and positive_integer?(height)
  defp valid_size?(_size), do: false

  defp valid_root?(nil), do: true

  defp valid_root?({module, assigns}),
    do: is_atom(module) and (is_map(assigns) or is_list(assigns))

  defp valid_root?(_root), do: false

  defp positive_integer?(value), do: is_integer(value) and value > 0
end
