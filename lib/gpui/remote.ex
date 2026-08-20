defmodule GPUI.Remote do
  @moduledoc "Shared child-spec construction for remote GPUI supervision trees."

  @doc "Builds a standard child specification for an internal remote process."
  @spec child_spec(module(), keyword()) :: Supervisor.child_spec()
  def child_spec(module, opts) do
    %{
      id: Keyword.get(opts, :id, Keyword.get(opts, :name, module)),
      start: {module, :start_link, [opts]}
    }
  end
end
