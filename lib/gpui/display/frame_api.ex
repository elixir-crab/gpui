defmodule GPUI.Display.FrameAPI do
  @moduledoc "Macro that adds the common rendered-frame API to display processes."

  defmacro __using__(_opts) do
    quote do
      @doc "Waits until a complete display frame follows the current window state."
      @spec await_frame(GenServer.server(), pos_integer(), pos_integer()) ::
              :ok | {:error, term()}
      def await_frame(server, window_id, timeout \\ 5_000),
        do: GPUI.Display.call_await_frame(server, window_id, timeout)

      @doc "Returns the latest completed display frame generation for a window."
      @spec frame_token(GenServer.server(), pos_integer()) ::
              {:ok, non_neg_integer()} | {:error, term()}
      def frame_token(server, window_id), do: GPUI.Display.call_frame_token(server, window_id)

      @doc "Waits for a display frame completed after the supplied generation."
      @spec await_frame_after(
              GenServer.server(),
              pos_integer(),
              non_neg_integer(),
              pos_integer()
            ) :: :ok | {:error, term()}
      def await_frame_after(server, window_id, generation, timeout \\ 5_000),
        do: GPUI.Display.call_await_frame_after(server, window_id, generation, timeout)
    end
  end
end
