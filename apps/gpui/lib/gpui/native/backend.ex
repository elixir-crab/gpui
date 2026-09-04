defmodule GPUI.Native.Backend do
  @moduledoc """
  Internal adapter for the configured native backend.

  The adapter verifies backend availability before dispatch so higher-level APIs
  can return a structured error when `gpui_native` is absent. It is documented
  for maintainers but excluded from the package's public API reference.
  """

  @default_backend GPUI.Native.NIF

  @doc "Returns the configured native backend module."
  @spec module() :: module()
  def module do
    Application.get_env(:gpui, :native_backend, @default_backend)
  end

  @doc "Reports whether the configured backend loaded a native implementation."
  @spec available?() :: boolean()
  def available? do
    backend = module()

    Code.ensure_loaded?(backend) and function_exported?(backend, :compiled?, 0) and
      backend.compiled?()
  end

  @doc "Calls a backend operation or returns `{:error, :native_backend_unavailable}`."
  @spec call(atom(), [term()]) :: term()
  def call(function, arguments) when is_atom(function) and is_list(arguments) do
    backend = module()

    if Code.ensure_loaded?(backend) and function_exported?(backend, function, length(arguments)) do
      apply(backend, function, arguments)
    else
      {:error, :native_backend_unavailable}
    end
  end

  use GPUI.Native.Facade
end
