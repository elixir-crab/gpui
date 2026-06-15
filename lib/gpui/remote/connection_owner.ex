defmodule GPUI.Remote.ConnectionOwner do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    {:ok,
     %{
       server: Keyword.fetch!(opts, :server),
       connection_id: Keyword.fetch!(opts, :connection_id)
     }}
  end

  @impl GenServer
  def handle_call({:dispatch, request}, _from, state) do
    reply = GenServer.call(state.server, {:dispatch, state.connection_id, request}, :infinity)
    {:reply, reply, state}
  end
end
