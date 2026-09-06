defmodule GPUI.Runtime.Update do
  @moduledoc """
  A synchronized runtime update delivered to `GPUI.Runtime` subscribers.

  `revision` increases monotonically within one runtime. `events` contains the
  normalized events handled to produce `snapshot`.
  """

  @enforce_keys [:revision, :events, :snapshot]
  defstruct [:revision, :events, :snapshot]

  @type t :: %__MODULE__{
          revision: pos_integer(),
          events: [GPUI.Event.payload()],
          snapshot: GPUI.Snapshot.t()
        }
end
