defmodule GPUI.Schema.Extension.Support do
  @moduledoc "Bounded display support for one exact presentation contract version."

  @max_contracts 64

  @enforce_keys [:id, :version, :capabilities]
  defstruct [:id, :version, :capabilities]

  @type t :: %__MODULE__{
          id: atom(),
          version: pos_integer(),
          capabilities: [atom()]
        }

  @doc "Maximum extension contracts advertised by one display or remote peer."
  @spec max_contracts() :: pos_integer()
  def max_contracts, do: @max_contracts

  @doc "Tests whether support provides one exact contract version and optional capability."
  @spec provides?(t(), atom(), pos_integer(), atom() | nil) :: boolean()
  def provides?(%__MODULE__{} = support, id, version, capability \\ nil) do
    support.id == id and support.version == version and
      (is_nil(capability) or capability in support.capabilities)
  end

  @doc "Builds and validates support against the canonical schema contract."
  @spec new(atom(), pos_integer(), [atom()]) :: {:ok, t()} | {:error, term()}
  def new(id, version, capabilities)
      when is_atom(id) and is_integer(version) and version > 0 and is_list(capabilities) do
    with {:ok, contract} <- fetch_contract(id),
         :ok <- exact_version(contract, version),
         :ok <- validate_capabilities(contract, capabilities) do
      {:ok, %__MODULE__{id: id, version: version, capabilities: capabilities}}
    end
  end

  def new(_id, _version, _capabilities), do: {:error, :invalid_extension_support}

  defp fetch_contract(id) do
    {:ok, GPUI.Schema.extension(id)}
  rescue
    ArgumentError -> {:error, {:unknown_extension, id}}
  end

  defp exact_version(%{version: version}, version), do: :ok

  defp exact_version(%{version: expected}, got),
    do: {:error, {:unsupported_version, expected, got}}

  defp validate_capabilities(contract, capabilities) do
    unknown = capabilities -- contract.capabilities
    max_capabilities = GPUI.Schema.Extension.max_capabilities()

    cond do
      Enum.count_until(capabilities, max_capabilities + 1) > max_capabilities ->
        {:error, :too_many_capabilities}

      Enum.uniq(capabilities) != capabilities ->
        {:error, :duplicate_capabilities}

      not Enum.all?(capabilities, &is_atom/1) ->
        {:error, :invalid_capability}

      unknown != [] ->
        {:error, {:unknown_capabilities, unknown}}

      true ->
        :ok
    end
  end
end
