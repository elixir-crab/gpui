defmodule GPUI.WindowSpec do
  @moduledoc """
  Declarative window specification returned by the application DSL.

  Each window owns a bounded set of platform-aware `GPUI.Command` bindings in
  addition to its title, size, and root view.
  """

  @max_key_bytes 128
  @max_title_bytes 512

  @type root :: {module(), map() | keyword()}
  @type key :: String.t()
  @type chrome :: :system | :content
  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          key: key() | nil,
          title: String.t(),
          size: {pos_integer(), pos_integer()} | nil,
          min_size: {pos_integer(), pos_integer()} | nil,
          resizable: boolean(),
          chrome: chrome(),
          root: root() | nil,
          commands: [GPUI.Command.t()]
        }

  @enforce_keys [:title]
  defstruct [
    :id,
    :key,
    :title,
    :size,
    :min_size,
    :root,
    resizable: true,
    chrome: :system,
    commands: []
  ]

  @spec validate!(t()) :: t()
  def validate!(
        %__MODULE__{
          title: title,
          key: key,
          size: size,
          min_size: min_size,
          resizable: resizable,
          chrome: chrome,
          root: root,
          commands: commands
        } = window
      ) do
    validate_title!(title)
    validate_key!(key)

    unless valid_size?(size) do
      raise ArgumentError, "window size must contain positive integer width and height"
    end

    unless valid_size?(min_size) do
      raise ArgumentError, "window minimum size must contain positive integer width and height"
    end

    unless is_boolean(resizable), do: raise(ArgumentError, "window resizable must be a boolean")

    unless chrome in [:system, :content],
      do: raise(ArgumentError, "window chrome must be :system or :content")

    unless valid_root?(root) do
      raise ArgumentError, "window root must contain a module and map or keyword assigns"
    end

    GPUI.Command.validate_all!(commands)

    if match?({_, _}, root) do
      {module, _assigns} = root

      unless Code.ensure_loaded?(module) and function_exported?(module, :render, 1) do
        raise ArgumentError, "window root #{inspect(module)} must implement render/1"
      end
    end

    window
  end

  defp validate_title!(title) when is_binary(title) and byte_size(title) <= @max_title_bytes,
    do: :ok

  defp validate_title!(title) when is_binary(title),
    do: raise(ArgumentError, "window title must be at most #{@max_title_bytes} bytes")

  defp validate_title!(_title), do: raise(ArgumentError, "window title must be a string")

  defp validate_key!(nil), do: :ok

  defp validate_key!(key)
       when is_binary(key) and key != "" and byte_size(key) <= @max_key_bytes,
       do: :ok

  defp validate_key!(key) when is_binary(key),
    do: raise(ArgumentError, "window key must contain 1 through #{@max_key_bytes} bytes")

  defp validate_key!(_key), do: raise(ArgumentError, "window key must be a non-empty string")

  defp valid_size?(nil), do: true
  defp valid_size?({width, height}), do: positive_integer?(width) and positive_integer?(height)
  defp valid_size?(_size), do: false

  defp valid_root?(nil), do: true

  defp valid_root?({module, assigns}),
    do: is_atom(module) and (is_map(assigns) or is_list(assigns))

  defp valid_root?(_root), do: false

  defp positive_integer?(value), do: is_integer(value) and value > 0
end
