defmodule GPUI.Runtime.Error do
  @moduledoc "Exception raised by a bang runtime operation when its non-bang form returns an error."

  defexception [:operation, :reason]

  @impl Exception
  def message(%__MODULE__{operation: operation, reason: reason}) do
    "GPUI runtime #{operation} failed: #{inspect(reason)}"
  end
end
