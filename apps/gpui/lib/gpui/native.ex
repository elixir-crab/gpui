defmodule GPUI.Native do
  @moduledoc "Backend-neutral native boundary used by GPUI runtime and resource APIs."

  @default_backend GPUI.Native.NIF

  @doc "Returns the configured native backend module."
  @spec backend() :: module()
  def backend do
    Application.get_env(:gpui, :native_backend, @default_backend)
  end

  @doc "Reports whether the configured backend loaded a native implementation."
  @spec compiled?() :: boolean()
  def compiled? do
    backend = backend()

    Code.ensure_loaded?(backend) and function_exported?(backend, :compiled?, 0) and
      backend.compiled?()
  end

  use GPUI.Native.Facade
end
