defmodule GPUI.Remote.Request do
  @moduledoc "Normalizes and bounds incoming SafeRPC request envelopes."

  defstruct [:kind, :op, :payload, :cap]

  @type t :: %__MODULE__{
          kind: atom() | nil,
          op: atom() | nil,
          payload: term(),
          cap: atom() | nil
        }

  @spec dispatch(term(), term(), term(), (t(), term(), term() -> term())) :: term()
  def dispatch(request, connection_id, state, dispatcher) when is_map(request) do
    request
    |> new()
    |> dispatcher.(connection_id, state)
  end

  def dispatch(_request, _connection_id, state, _dispatcher),
    do: {{:error, :unsupported_request}, state}

  @spec new(map()) :: t()
  def new(request) when is_map(request) do
    %__MODULE__{
      kind: Map.get(request, :kind),
      op: Map.get(request, :op),
      payload: Map.get(request, :payload, %{}),
      cap: Map.get(request, :cap)
    }
  end
end
