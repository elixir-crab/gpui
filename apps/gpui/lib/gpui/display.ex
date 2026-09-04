defmodule GPUI.Display do
  @moduledoc """
  Behaviour for displays that present GPUI snapshots and return input events.

  Displays own renderer-specific lifecycle and resources while application
  sessions remain renderer-independent. Implementations provide process startup,
  snapshot synchronization, event draining, and deterministic event injection.
  Frame barriers and presentation capabilities are optional.

  Framework runtimes invoke this contract through `GPUI.Display.Support`, which
  validates callback results and turns callback failures into structured errors.
  """

  @type snapshot :: GPUI.Snapshot.t()
  @type event :: GPUI.Event.payload()

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback sync(GenServer.server(), snapshot()) :: :ok | {:error, term()}
  @callback drain_events(GenServer.server()) :: {:ok, [event()]} | {:error, term()}
  @callback inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
  @callback await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
              :ok | {:error, term()}
  @callback frame_token(GenServer.server(), pos_integer()) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback await_frame_after(
              GenServer.server(),
              pos_integer(),
              non_neg_integer(),
              pos_integer()
            ) :: :ok | {:error, term()}

  @callback presentation_capabilities(GenServer.server()) ::
              {:ok, [GPUI.Schema.Extension.Support.t()]} | {:error, term()}

  @optional_callbacks await_frame: 3,
                      frame_token: 2,
                      await_frame_after: 4,
                      presentation_capabilities: 1
end
