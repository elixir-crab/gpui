defmodule GPUI.View do
  @moduledoc """
  Behaviour for Elixir-rendered GPUI views.
  """

  alias GPUI.Element

  @callback render(map()) :: Element.t()
  @callback handle_event(atom(), map(), map()) :: {:noreply, map()} | {:reply, term(), map()}

  defmacro __using__(_opts) do
    quote do
      @behaviour GPUI.View

      import Kernel, except: [div: 2]
      import GPUI
      import GPUI.Template, only: [sigil_GPUI: 2]

      @impl GPUI.View
      def handle_event(_event, _payload, state), do: {:noreply, state}

      defoverridable handle_event: 3
    end
  end
end
