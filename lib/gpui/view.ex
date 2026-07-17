defmodule GPUI.View do
  @moduledoc """
  Behaviour for Elixir-rendered GPUI views.

  Views render from assigns, handle native input through `handle_event/3`, and
  receive supervised application updates through `handle_info/2` when a caller
  uses `GPUI.Runtime.send_view/3`.
  """

  alias GPUI.Element

  @callback render(map()) :: Element.t()
  @callback handle_event(String.t(), map(), map()) :: {:noreply, map()} | {:reply, term(), map()}
  @callback handle_info(term(), map()) :: {:noreply, map()}

  @optional_callbacks handle_info: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour GPUI.View

      import Kernel, except: [div: 2]
      import GPUI
      import GPUI.Template, only: [sigil_GPUI: 2]

      @impl GPUI.View
      def handle_event(_event, _payload, state), do: {:noreply, state}

      @impl GPUI.View
      def handle_info(_message, state), do: {:noreply, state}

      defoverridable handle_event: 3, handle_info: 2
    end
  end
end
