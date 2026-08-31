defmodule GPUI.Application.Icon do
  @moduledoc """
  Application-owned icon source metadata.

  `source` is a relative path to an icon asset or asset directory. Platform
  packaging remains responsible for producing bundle, executable, and desktop
  integration resources.
  """

  @enforce_keys [:source]
  defstruct [:source, :description]

  @type t :: %__MODULE__{source: String.t(), description: String.t() | nil}

  @spec new!(keyword() | map()) :: t()
  def new!(attrs), do: attrs |> then(&struct!(__MODULE__, &1)) |> validate!()

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{source: source, description: description} = icon) do
    unless valid_source?(source) do
      raise ArgumentError,
            "application icon source must be a bounded relative path without traversal"
    end

    unless is_nil(description) or
             (is_binary(description) and String.valid?(description) and description != "" and
                byte_size(description) <= 512) do
      raise ArgumentError,
            "application icon description must be bounded non-empty UTF-8 text or nil"
    end

    icon
  end

  defp valid_source?(source)
       when is_binary(source) and source != "" and byte_size(source) <= 1_024 do
    String.valid?(source) and Path.type(source) == :relative and
      Enum.all?(Path.split(source), &(&1 not in ["..", "."]))
  end

  defp valid_source?(_source), do: false
end
