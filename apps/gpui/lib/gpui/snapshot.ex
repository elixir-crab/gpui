defmodule GPUI.Snapshot do
  @moduledoc """
  Renderer-independent snapshot of a running `GPUI.Session`.

  Snapshots are the only state transferred from sessions to local or remote
  displays.
  """

  @enforce_keys [:windows, :resources]
  defstruct [:windows, :resources]

  @type t :: %__MODULE__{
          windows: [GPUI.Snapshot.Window.t()],
          resources: %{optional(String.t()) => map()}
        }
end
