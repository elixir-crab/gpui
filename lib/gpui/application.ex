defmodule GPUI.Application do
  @moduledoc """
  Behaviour and DSL for OTP-supervised GPUI applications.

  `mount/1` declares a session's initial windows. Interactive state belongs to
  each root view's assigns rather than an unused application-level state value.
  """

  alias GPUI.WindowSpec

  @doc "Builds the initial renderer-independent window set for a session."
  @callback mount(term()) :: {:ok, [WindowSpec.t()]}

  defmacro __using__(_opts) do
    quote do
      @behaviour GPUI.Application

      import GPUI.Application, only: [window: 2, size: 2, root: 1, root: 2]

      def child_spec(opts) do
        %{
          id: Keyword.get(opts, :id, Keyword.get(opts, :name, __MODULE__)),
          start: {GPUI.Runtime, :start_link, [Keyword.put(opts, :app, __MODULE__)]}
        }
      end
    end
  end

  @doc "Builds a window specification from a DSL block."
  defmacro window(title, do: block) do
    entries = block_entries(block)

    quote do
      Enum.reduce(unquote(entries), %GPUI.WindowSpec{title: unquote(title)}, fn
        {:size, width, height}, spec -> %{spec | size: {width, height}}
        {:root, module, assigns}, spec -> %{spec | root: {module, Map.new(assigns)}}
      end)
    end
  end

  @doc "Declares a window size inside `window`."
  defmacro size(width, height), do: quote(do: {:size, unquote(width), unquote(height)})

  @doc "Declares a root view inside `window`."
  defmacro root(module, assigns \\ []) do
    quote do
      {:root, unquote(module), unquote(assigns)}
    end
  end

  defp block_entries({:__block__, _meta, expressions}), do: expressions
  defp block_entries(expression), do: [expression]
end
