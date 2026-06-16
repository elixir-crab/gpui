defmodule GPUI.Remote.ProtocolNegotiation do
  @moduledoc false

  @spec negotiate(map(), pos_integer(), [atom()], [atom()]) ::
          {:ok, map()}
          | {:error, {:incompatible_version, map()} | {:missing_capabilities, [atom()]}}
  def negotiate(%{version: version}, expected_version, _required, _provided)
      when version != expected_version do
    {:error, {:incompatible_version, %{expected: expected_version, got: version}}}
  end

  def negotiate(payload, version, required_capabilities, provided_capabilities)
      when is_map(payload) do
    capabilities = Map.get(payload, :capabilities, [])

    case required_capabilities -- capabilities do
      [] -> {:ok, %{version: version, capabilities: provided_capabilities}}
      missing -> {:error, {:missing_capabilities, missing}}
    end
  end
end
