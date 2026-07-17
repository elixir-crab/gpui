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
  @callback frame_token(GenServer.server(), pos_integer()) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback await_frame_after(
              GenServer.server(),
              pos_integer(),
              non_neg_integer(),
              pos_integer()
            ) :: :ok | {:error, term()}

  @optional_callbacks await_frame: 3, frame_token: 2, await_frame_after: 4

  @doc false
  @spec call_await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
          :ok | {:error, term()}
  def call_await_frame(server, window_id, timeout)
      when is_integer(window_id) and window_id > 0 and is_integer(timeout) and timeout > 0 do
    GenServer.call(server, {:await_frame, window_id, timeout}, timeout + 2_000)
  end

  @doc false
  @spec call_frame_token(GenServer.server(), pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def call_frame_token(server, window_id) when is_integer(window_id) and window_id > 0 do
    GenServer.call(server, {:frame_token, window_id}, 7_000)
  end

  @doc false
  @spec call_await_frame_after(
          GenServer.server(),
          pos_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: :ok | {:error, term()}
  def call_await_frame_after(server, window_id, generation, timeout)
      when is_integer(window_id) and window_id > 0 and is_integer(generation) and generation >= 0 and
             is_integer(timeout) and timeout > 0 do
    GenServer.call(
      server,
      {:await_frame_after, window_id, generation, timeout},
      timeout + 2_000
    )
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
  def reply_after_frame(display_module, display, window_id, timeout, from),
    do: reply_from_display(display_module, display, :await_frame, [window_id, timeout], from)

  @doc false
  @spec reply_from_display(module(), GenServer.server(), atom(), [term()], GenServer.from()) ::
          :ok
  def reply_from_display(display_module, display, callback, args, from) do
    Task.start(fn ->
      reply =
        if function_exported?(display_module, callback, length(args) + 1) do
          apply(display_module, callback, [display | args])
        else
          {:error, :unsupported}
        end

      GenServer.reply(from, reply)
    end)

    :ok
  end
end
