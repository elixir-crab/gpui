defmodule GPUI.Display do
  @moduledoc """
  Display boundary for rendered GPUI session snapshots and native input events.

  Displays own renderer-specific lifecycle and resources. Application sessions
  remain renderer-independent.
  """

  @type snapshot :: GPUI.Snapshot.t()
  @type event :: map() | keyword() | String.t()

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback sync(GenServer.server(), snapshot()) :: :ok | {:error, term()}
  @callback drain_events(GenServer.server()) :: {:ok, [event()]} | {:error, term()}
  @callback inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
end
