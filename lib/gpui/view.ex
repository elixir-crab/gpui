defmodule GPUI.View do
  @moduledoc """
  Behaviour for Elixir-rendered GPUI views.

  Views render from assigns, handle native input through `handle_event/3`, and
  receive supervised application updates through `handle_info/2` when a caller
  uses `GPUI.Runtime.send_view/3`.
  """

  alias GPUI.Element

  @type window_event :: :close_request | :focus | :blur

  @type callback_result ::
          {:noreply, map()}
          | {:close, map()}
          | {:open_window, GPUI.WindowSpec.t(), map()}
          | {:close_window, GPUI.WindowSpec.key() | pos_integer(), map()}

  @callback render(map()) :: Element.t()
  @callback handle_event(String.t(), map(), map()) :: callback_result()
  @callback handle_window_event(window_event(), map(), map()) ::
              {:noreply, map()} | {:close, map()}
  @callback handle_info(term(), map()) :: callback_result()

  @optional_callbacks handle_info: 2, handle_window_event: 3

  defmacro __using__(_opts) do
    quote do
      @behaviour GPUI.View

      import Kernel, except: [div: 2]
      import GPUI
      import GPUI.Template, only: [sigil_GPUI: 2]
      import GPUI.Color, only: [sigil_RGB: 2, sigil_RGBA: 2]

      @impl GPUI.View
      def handle_event(_event, _payload, state), do: {:noreply, state}

      @impl GPUI.View
      def handle_info(_message, state), do: {:noreply, state}

      defoverridable handle_event: 3, handle_info: 2
    end
  end
end
