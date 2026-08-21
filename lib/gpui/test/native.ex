defmodule GPUI.Test.Native do
  @moduledoc """
  Elixir-facing deterministic native renderer tests backed by GPUI's
  `TestAppContext`.

  This module keeps fixtures and assertions in ExUnit while the native boundary
  only interprets a small, renderer-neutral command vocabulary.
  """

  @enforce_keys [:id]
  defstruct [:id]

  @type t :: %__MODULE__{id: pos_integer()}

  @doc "Starts an isolated deterministic GPUI test window."
  @spec start!(keyword()) :: t()
  def start!(opts \\ []) do
    width = Keyword.get(opts, :width, 640)
    height = Keyword.get(opts, :height, 480)
    {:ok, id} = GPUI.Native.native_test_start(width, height)
    %__MODULE__{id: id}
  end

  @doc "Renders a view through the native renderer with map or keyword assigns."
  @spec render_view!(t(), module(), map() | keyword()) :: t()
  def render_view!(test, view, assigns \\ %{}) do
    tree = view |> GPUI.Test.render(assigns) |> GPUI.Element.to_payload()
    render!(test, viewport(tree))
  end

  defp viewport(tree), do: Map.new(type: :viewport, attrs: %{}, children: [tree])

  @doc "Renders a snapshot-encoded element tree through the native renderer."
  @spec render!(t(), map()) :: t()
  def render!(%__MODULE__{id: id} = test, tree) when is_map(tree) do
    {:ok, :ok} = GPUI.Native.native_test_render(id, tree)
    test
  end

  @doc "Focuses a stable renderer element ID."
  @spec focus!(t(), String.t()) :: t()
  def focus!(%__MODULE__{id: id} = test, element_id) when is_binary(element_id) do
    {:ok, :ok} = GPUI.Native.native_test_focus(id, element_id)
    test
  end

  @doc "Dispatches one GPUI keystroke using GPUI's test vocabulary."
  @spec key!(t(), String.t()) :: t()
  def key!(%__MODULE__{id: id} = test, key) when is_binary(key) do
    {:ok, :ok} = GPUI.Native.native_test_key(id, key)
    test
  end

  @doc "Drains native events emitted since the previous call."
  @spec events!(t()) :: [map()]
  def events!(%__MODULE__{id: id}) do
    {:ok, events} = GPUI.Native.native_test_events(id)
    events
  end

  @doc "Stops the deterministic native test session."
  @spec stop(t()) :: :ok
  def stop(%__MODULE__{id: id}) do
    case GPUI.Native.native_test_stop(id) do
      {:ok, :ok} -> :ok
      {:error, "unknown_native_test"} -> :ok
    end
  end
end
