defmodule GPUI.Display do
  @moduledoc """
  Display boundary for rendered GPUI session snapshots and native input events.

  Displays own renderer-specific lifecycle and resources. Application sessions
  remain renderer-independent.
  """

  @type snapshot :: GPUI.Snapshot.t()
  @type event :: map()

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback sync(GenServer.server(), snapshot()) :: :ok | {:error, term()}
  @callback drain_events(GenServer.server()) :: {:ok, [event()]} | {:error, term()}
  @callback inject_event(GenServer.server(), map()) :: {:ok, term()} | {:error, term()}
  @callback await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
              :ok | {:error, term()}

  @optional_callbacks await_frame: 3

  @doc false
  @spec call_await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
          :ok | {:error, term()}
  def call_await_frame(server, window_id, timeout)
      when is_integer(window_id) and window_id > 0 and is_integer(timeout) and timeout > 0 do
    GenServer.call(server, {:await_frame, window_id, timeout}, timeout + 2_000)
  end

  @doc false
  @spec reply_after_frame(
          module(),
          GenServer.server(),
          pos_integer(),
          pos_integer(),
          GenServer.from()
        ) ::
          :ok
  def reply_after_frame(display_module, display, window_id, timeout, from) do
    Task.start(fn ->
      reply =
        if function_exported?(display_module, :await_frame, 3) do
          display_module.await_frame(display, window_id, timeout)
        else
          {:error, :unsupported}
        end

      GenServer.reply(from, reply)
    end)

    :ok
  end
end
