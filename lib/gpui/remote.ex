defmodule GPUI.Remote do
  @moduledoc """
  Remote session and display support over the versioned GPUI protocol.
  """

  @doc false
  @spec child_spec(module(), keyword()) :: Supervisor.child_spec()
  def child_spec(module, opts) do
    %{
      id: Keyword.get(opts, :id, Keyword.get(opts, :name, module)),
      start: {module, :start_link, [opts]}
    }
  end
end
