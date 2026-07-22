defmodule GPUI.Command do
  @moduledoc """
  Declarative application command bound to a modified keyboard shortcut.

  Command IDs are the same non-empty event names used by buttons and menus.
  Shortcuts use `primary` for Command on macOS and Control elsewhere, with
  optional `ctrl`, `alt`, and `shift` modifiers, for example `primary-r` or
  `primary-shift-p`.
  """

  @enforce_keys [:id, :shortcut]
  defstruct [:id, :shortcut]

  @type t :: %__MODULE__{id: String.t(), shortcut: String.t()}

  @max_commands 64
  @max_id_bytes 128
  @max_shortcut_bytes 64
  @modifiers ~w(primary ctrl alt shift)

  @doc "Builds and validates one application command."
  @spec new(String.t(), String.t()) :: t()
  def new(id, shortcut), do: validate!(%__MODULE__{id: id, shortcut: shortcut})

  @doc false
  @spec validate_all!([t()]) :: [t()]
  def validate_all!(commands) when is_list(commands) and length(commands) <= @max_commands do
    commands = Enum.map(commands, &validate!/1)
    reject_duplicates!(commands, & &1.id, "command id")
    reject_duplicates!(commands, & &1.shortcut, "command shortcut")
    commands
  end

  def validate_all!(commands) when is_list(commands) do
    raise ArgumentError, "a window supports at most #{@max_commands} commands"
  end

  def validate_all!(commands) do
    raise ArgumentError, "window commands must be a list; got: #{inspect(commands)}"
  end

  @doc false
  @spec to_payload(t()) :: {String.t(), String.t()}
  def to_payload(%__MODULE__{} = command), do: {command.id, command.shortcut}

  defp validate!(%__MODULE__{id: id, shortcut: shortcut} = command) do
    validate_id!(id)
    validate_shortcut!(shortcut)
    command
  end

  defp validate!(command) do
    raise ArgumentError, "window commands must be GPUI.Command values; got: #{inspect(command)}"
  end

  defp validate_id!(id)
       when is_binary(id) and id != "" and byte_size(id) <= @max_id_bytes,
       do: :ok

  defp validate_id!(id) do
    raise ArgumentError,
          "command id must be a non-empty string of at most #{@max_id_bytes} bytes; got: #{inspect(id)}"
  end

  defp validate_shortcut!(shortcut)
       when is_binary(shortcut) and shortcut != "" and byte_size(shortcut) <= @max_shortcut_bytes do
    parts = String.split(shortcut, "-")
    modifiers = Enum.drop(parts, -1)
    key = List.last(parts)

    unless valid_modifiers?(modifiers) and valid_key?(key) do
      raise ArgumentError,
            "command shortcut must contain primary, ctrl, or alt plus one lowercase key; " <>
              "got: #{inspect(shortcut)}"
    end
  end

  defp validate_shortcut!(shortcut) do
    raise ArgumentError,
          "command shortcut must be a non-empty string of at most #{@max_shortcut_bytes} bytes; " <>
            "got: #{inspect(shortcut)}"
  end

  defp valid_modifiers?(modifiers) do
    {known?, activation_modifier?} =
      Enum.reduce(modifiers, {true, false}, fn modifier, {known?, activation?} ->
        {known? and modifier in @modifiers, activation? or modifier in ~w(primary ctrl alt)}
      end)

    modifiers != [] and known? and activation_modifier? and
      modifiers == Enum.filter(@modifiers, &(&1 in modifiers)) and
      length(modifiers) == MapSet.size(MapSet.new(modifiers))
  end

  defp valid_key?(key), do: is_binary(key) and Regex.match?(~r/^[a-z0-9]$/, key)

  defp reject_duplicates!(commands, key, description) do
    values = Enum.map(commands, key)

    if length(values) != MapSet.size(MapSet.new(values)) do
      raise ArgumentError, "window #{description}s must be unique"
    end
  end
end
