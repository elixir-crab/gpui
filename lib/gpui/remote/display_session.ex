defmodule GPUI.Remote.DisplaySession do
  @moduledoc false

  alias GPUI.Remote.SessionGC

  defstruct events: [], windows: %{}, resources: %{}, last_seen: nil

  @type t :: %__MODULE__{
          events: [map()],
          windows: %{optional(term()) => map()},
          resources: %{optional(term()) => map()},
          last_seen: integer() | nil
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      events: Keyword.get(opts, :events, []),
      windows: Keyword.get(opts, :windows, %{}),
      resources: Keyword.get(opts, :resources, %{}),
      last_seen: Keyword.get_lazy(opts, :last_seen, &SessionGC.monotonic_ms/0)
    }
  end
end
