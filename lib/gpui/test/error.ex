defmodule GPUI.Test.Error do
  @moduledoc "Raised when a deterministic native UI operation fails."

  defexception [:operation, :subject, :reason, :ui]

  @impl Exception
  def message(%__MODULE__{} = error) do
    subject = if is_nil(error.subject), do: "", else: " for #{inspect(error.subject)}"
    "GPUI native test #{error.operation} failed#{subject}: #{error.reason}"
  end
end
