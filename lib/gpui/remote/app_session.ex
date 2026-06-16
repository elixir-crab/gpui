defmodule GPUI.Remote.AppSession do
  @moduledoc false

  alias GPUI.Remote.SessionGC

  defstruct [:runtime, app_args: [], last_seen: nil]

  @type t :: %__MODULE__{
          runtime: pid() | nil,
          app_args: term(),
          last_seen: integer() | nil
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      runtime: Keyword.get(opts, :runtime),
      app_args: Keyword.get(opts, :app_args, []),
      last_seen: Keyword.get_lazy(opts, :last_seen, &SessionGC.monotonic_ms/0)
    }
  end
end
