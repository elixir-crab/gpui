defmodule GPUI.Remote.ServerCallbacks do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @impl GenServer
      def handle_call(:port, _from, state),
        do: {:reply, GPUI.Remote.ServerConnection.port(state), state}

      def handle_call({:dispatch, connection_id, request}, _from, state) do
        {reply, state} = dispatch(request, connection_id, state)
        {:reply, reply, state}
      end

      def handle_call({:dispatch, request}, _from, state) do
        {reply, state} = dispatch(request, :legacy, state)
        {:reply, reply, state}
      end

      @impl GenServer
      def handle_info({:gpui_remote_accepted, socket}, state),
        do: {:noreply, GPUI.Remote.ServerConnection.accept(state, socket)}

      def handle_info({:gpui_remote_accept_error, reason}, state),
        do: {:stop, {:accept_failed, reason}, state}

      def handle_info({:DOWN, _ref, :process, pid, _reason}, state),
        do: {:noreply, GPUI.Remote.ServerConnection.remove(state, pid)}

      def handle_info(:gc_sessions, state) do
        state = gc_sessions(state)
        schedule_session_gc(state)
        {:noreply, state}
      end
    end
  end
end
