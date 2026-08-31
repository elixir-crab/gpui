defmodule GPUI.Application.Identity do
  @moduledoc """
  Stable process-wide identity for a GPUI application.

  The identifier should use reverse-DNS form. `icon` names an application-owned
  source asset or asset set; platform release tooling remains responsible for
  producing macOS bundles, Windows resources, and Linux desktop entries.
  """

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :icon]

  @type t :: %__MODULE__{id: String.t(), name: String.t(), icon: String.t() | nil}

  @spec new!(keyword() | map()) :: t()
  def new!(attrs) do
    identity = struct!(__MODULE__, attrs)
    validate!(identity)
  end

  @spec validate!(t()) :: t()
  def validate!(%__MODULE__{id: id, name: name, icon: icon} = identity) do
    unless is_binary(id) and byte_size(id) in 3..255 and
             Regex.match?(~r/^[A-Za-z0-9]+(?:[.-][A-Za-z0-9_-]+)+$/, id) do
      raise ArgumentError, "application identity id must be a bounded reverse-DNS identifier"
    end

    unless is_binary(name) and String.trim(name) != "" and byte_size(name) <= 255 do
      raise ArgumentError, "application identity name must be non-empty UTF-8 text"
    end

    unless is_nil(icon) or (is_binary(icon) and icon != "" and byte_size(icon) <= 1_024) do
      raise ArgumentError, "application identity icon must be a bounded asset path or nil"
    end

    identity
  end
end
