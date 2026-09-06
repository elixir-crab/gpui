defmodule GPUI.Display.Support do
  @moduledoc """
  Runtime support for invoking and coordinating `GPUI.Display` implementations.

  This module centralizes callback validation, asynchronous frame replies, and
  frame-call plumbing. Display implementers normally need only the
  `GPUI.Display` behaviour; framework runtimes use this support layer.
  """

  @type snapshot :: GPUI.Snapshot.t()
  @type event :: GPUI.Event.payload()

  @doc "Starts a display module and normalizes its startup result."
  @spec start(module(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start(display_module, opts) do
    case invoke(display_module, :start_link, [opts]) do
      {:ok, pid} when is_pid(pid) -> {:ok, pid}
      {:error, _reason} = error -> error
      invalid -> {:error, {:invalid_display_return, :start_link, invalid}}
    end
  end

  @doc "Synchronizes a renderer-independent snapshot through a display module."
  @spec sync_snapshot(module(), GenServer.server(), snapshot()) :: :ok | {:error, term()}
  def sync_snapshot(display_module, display, snapshot) do
    case invoke(display_module, :sync, [display, snapshot]) do
      :ok -> :ok
      {:error, _reason} = error -> error
      invalid -> {:error, {:invalid_display_return, :sync, invalid}}
    end
  end

  @doc "Drains pending native or test events from a display module."
  @spec drain(module(), GenServer.server()) :: {:ok, [event()]} | {:error, term()}
  def drain(display_module, display) do
    case invoke(display_module, :drain_events, [display]) do
      {:ok, events} when is_list(events) -> {:ok, events}
      {:error, _reason} = error -> error
      invalid -> {:error, {:invalid_display_return, :drain_events, invalid}}
    end
  end

  @doc "Injects one event into a display's pending event queue."
  @spec inject(module(), GenServer.server(), event()) :: {:ok, term()} | {:error, term()}
  def inject(display_module, display, event) do
    case invoke(display_module, :inject_event, [display, event]) do
      {:ok, _reply} = reply -> reply
      {:error, _reason} = error -> error
      invalid -> {:error, {:invalid_display_return, :inject_event, invalid}}
    end
  end

  @doc "Waits until a display has rendered the requested window frame."
  @spec call_await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
          :ok | {:error, term()}
  def call_await_frame(server, window_id, timeout)
      when is_integer(window_id) and window_id > 0 and is_integer(timeout) and timeout > 0 do
    GenServer.call(server, {:await_frame, window_id, timeout}, timeout + 2_000)
  end

  @doc "Returns the current rendered-frame generation for a display window."
  @spec call_frame_token(GenServer.server(), pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def call_frame_token(server, window_id) when is_integer(window_id) and window_id > 0 do
    GenServer.call(server, {:frame_token, window_id}, 7_000)
  end

  @doc "Waits for a frame generation newer than the supplied token."
  @spec call_await_frame_after(
          GenServer.server(),
          pos_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: :ok | {:error, term()}
  def call_await_frame_after(server, window_id, generation, timeout)
      when is_integer(window_id) and window_id > 0 and is_integer(generation) and generation >= 0 and
             is_integer(timeout) and timeout > 0 do
    GenServer.call(server, {:await_frame_after, window_id, generation, timeout}, timeout + 2_000)
  end

  @doc "Replies to a caller after the selected display frame completes."
  @spec reply_after_frame(
          module(),
          GenServer.server(),
          pos_integer(),
          pos_integer(),
          GenServer.from()
        ) :: :ok
  def reply_after_frame(display_module, display, window_id, timeout, from),
    do: reply_from_display(display_module, display, :await_frame, [window_id, timeout], from)

  @doc "Delegates a frame API call to a display and replies asynchronously."
  @spec reply_from_display(module(), GenServer.server(), atom(), [term()], GenServer.from()) ::
          :ok
  def reply_from_display(display_module, display, callback, args, from) do
    async_reply(from, fn ->
      if function_exported?(display_module, callback, length(args) + 1) do
        apply(display_module, callback, [display | args])
      else
        {:error, :unsupported}
      end
    end)
  end

  @doc "Returns bounded optional presentation support advertised by a display."
  @spec presentation_capabilities(module(), GenServer.server()) ::
          {:ok, [GPUI.Schema.Extension.Support.t()]} | {:error, term()}
  def presentation_capabilities(display_module, display) do
    if function_exported?(display_module, :presentation_capabilities, 1) do
      case invoke(display_module, :presentation_capabilities, [display]) do
        {:ok, supports} when is_list(supports) -> validate_presentation_support(supports)
        {:error, _reason} = error -> error
        invalid -> {:error, {:invalid_display_return, :presentation_capabilities, invalid}}
      end
    else
      {:ok, []}
    end
  end

  @doc "Runs work asynchronously and replies to the original GenServer caller."
  @spec async_reply(GenServer.from(), (-> term()), (term() -> term())) :: :ok
  def async_reply(from, callback, normalize \\ &Function.identity/1) do
    {:ok, _pid} =
      Task.start(fn ->
        reply = invoke_async(callback, normalize)
        GenServer.reply(from, reply)
      end)

    :ok
  end

  defp validate_presentation_support(supports) do
    max_contracts = GPUI.Schema.Extension.Support.max_contracts()

    if Enum.count_until(supports, max_contracts + 1) > max_contracts,
      do: {:error, {:invalid_display_return, :presentation_capabilities, :too_many_contracts}},
      else: collect_presentation_support(supports)
  end

  defp collect_presentation_support(supports) do
    supports
    |> Enum.reduce_while({:ok, []}, &collect_presentation_support/2)
    |> case do
      {:ok, valid} -> {:ok, Enum.reverse(valid)}
      error -> error
    end
  end

  defp collect_presentation_support(
         %GPUI.Schema.Extension.Support{id: id, version: version, capabilities: capabilities},
         {:ok, valid}
       ) do
    case GPUI.Schema.Extension.Support.new(id, version, capabilities) do
      {:ok, support} -> {:cont, {:ok, [support | valid]}}
      {:error, reason} -> {:halt, {:error, {:invalid_extension_support, reason}}}
    end
  end

  defp collect_presentation_support(invalid, _valid),
    do: {:halt, {:error, {:invalid_extension_support, invalid}}}

  defp invoke(display_module, callback, args) do
    apply(display_module, callback, args)
  catch
    kind, reason -> {:error, {:display_callback_failed, callback, kind, reason}}
  end

  defp invoke_async(callback, normalize) do
    callback.() |> normalize.()
  catch
    kind, reason -> {:error, {:display_callback_failed, kind, reason}}
  end
end
