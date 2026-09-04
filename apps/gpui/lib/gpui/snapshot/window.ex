defmodule GPUI.Snapshot.Window do
  @moduledoc """
  Typed shape of one serialized window in a `GPUI.Snapshot`.

  Window snapshots remain plain maps so they can cross local and remote display
  boundaries without conversion. This module supplies named map types for that
  stable in-process contract.
  """

  @type root :: %{
          required(:module) => String.t(),
          required(:assigns) => map(),
          required(:tree) => map()
        }

  @type t :: %{
          required(:id) => pos_integer(),
          required(:key) => String.t() | nil,
          required(:title) => String.t(),
          required(:size) => [pos_integer()],
          required(:min_size) => [pos_integer()] | nil,
          required(:resizable) => boolean(),
          required(:chrome) => GPUI.WindowSpec.chrome(),
          required(:lifecycle) => [GPUI.View.window_event()],
          required(:commands) => [{String.t(), String.t()}],
          required(:root) => root() | nil
        }
end
