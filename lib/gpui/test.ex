defmodule GPUI.Test do
  @moduledoc """
  ExUnit helpers for testing GPUI views and applications without a native window.

  Use this module from a test case to import deterministic runtime, event, and
  tree-query helpers:

      defmodule CounterTest do
        use GPUI.Test, async: true

        test "increments" do
          runtime = start_gpui!(CounterApp)

          assert %{count: 0} = assigns(runtime)
          click(runtime, "increment")
          assert %{count: 1} = assigns(runtime)
        end
      end

  Events are dispatched through `GPUI.Test.Display`, so the same
  `GPUI.Runtime` polling boundary used by a real display is exercised without
  loading GPUI or requiring desktop libraries.
  """

  alias GPUI.Element
  alias GPUI.Event
  alias GPUI.Runtime
  alias GPUI.Snapshot

  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)
      import GPUI.Test
    end
  end

  @doc "Starts a supervised runtime backed by `GPUI.Test.Display`."
  @spec start_gpui!(module(), keyword()) :: pid()
  def start_gpui!(app, opts \\ []) do
    runtime_opts =
      opts
      |> Keyword.put(:app, app)
      |> Keyword.put_new(:display, GPUI.Test.Display)
      |> Keyword.put_new(:poll_interval, nil)

    child_spec =
      Supervisor.child_spec({Runtime, runtime_opts}, id: {Runtime, make_ref()})

    ExUnit.Callbacks.start_supervised!(child_spec)
  end

  @doc "Renders a view directly with map or keyword assigns."
  @spec render(module(), map() | keyword()) :: Element.t()
  def render(view, assigns \\ %{}) do
    view.render(Map.new(assigns))
  end

  @doc "Returns a runtime snapshot, or passes an existing snapshot through."
  @spec snapshot(GenServer.server() | Snapshot.t()) :: Snapshot.t()
  def snapshot(%Snapshot{} = snapshot), do: snapshot
  def snapshot(runtime), do: Runtime.snapshot(runtime)

  @doc "Returns a window snapshot from a runtime or full snapshot."
  @spec window_snapshot(
          GenServer.server() | Snapshot.t(),
          :first | pos_integer() | String.t()
        ) :: map()
  def window_snapshot(source, selector \\ :first)

  def window_snapshot(source, :first) do
    case snapshot(source).windows do
      [window | _windows] -> window
      [] -> raise ArgumentError, "GPUI snapshot has no windows"
    end
  end

  def window_snapshot(source, selector) when is_integer(selector) do
    find_window!(source, &(&1.id == selector), "id #{selector}")
  end

  def window_snapshot(source, selector) when is_binary(selector) do
    find_window!(source, &(&1.title == selector), "title #{inspect(selector)}")
  end

  @doc "Returns root-view assigns for a selected window."
  @spec assigns(GenServer.server() | Snapshot.t(), :first | pos_integer() | String.t()) :: map()
  def assigns(source, selector \\ :first),
    do: source |> window_snapshot(selector) |> get_in([:root, :assigns])

  @doc "Returns the rendered tree for a selected window."
  @spec tree(GenServer.server() | Snapshot.t(), :first | pos_integer() | String.t()) :: map()
  def tree(source, selector \\ :first),
    do: source |> window_snapshot(selector) |> get_in([:root, :tree])

  @doc "Dispatches a normalized display event and returns handled events plus the new snapshot."
  @spec dispatch(GenServer.server(), Event.t() | map() | keyword()) :: {[map()], Snapshot.t()}
  def dispatch(runtime, event) do
    event = Event.normalize(event)

    case Runtime.inject_event(runtime, event) do
      {:ok, :ok} -> {Runtime.drain_events(runtime), Runtime.snapshot(runtime)}
      {:error, reason} -> raise "GPUI test display rejected event: #{inspect(reason)}"
    end
  end

  @doc "Dispatches a click event and returns the updated snapshot."
  @spec click(GenServer.server(), String.t(), keyword()) :: Snapshot.t()
  def click(runtime, event, opts \\ []) do
    {_handled, snapshot} =
      dispatch(runtime, %{
        type: :click,
        window_id: event_window_id(runtime, opts),
        event: event
      })

    snapshot
  end

  @doc "Dispatches a change event and returns the updated snapshot."
  @spec change(GenServer.server(), String.t(), term(), keyword()) :: Snapshot.t()
  def change(runtime, event, value, opts \\ []) do
    {_handled, snapshot} =
      dispatch(runtime, %{
        type: :change,
        window_id: event_window_id(runtime, opts),
        event: event,
        value: value
      })

    snapshot
  end

  @doc "Selects a controlled component option and returns the updated snapshot."
  @spec select(GenServer.server(), String.t(), String.t() | nil, keyword()) :: Snapshot.t()
  def select(runtime, event, value, opts \\ []), do: change(runtime, event, value, opts)

  @doc "Dispatches a combobox search event and returns the updated snapshot."
  @spec search(GenServer.server(), String.t(), String.t(), keyword()) :: Snapshot.t()
  def search(runtime, event, query, opts \\ []) do
    {_handled, snapshot} =
      dispatch(runtime, %{
        type: :search,
        window_id: event_window_id(runtime, opts),
        event: event,
        value: query
      })

    snapshot
  end

  @doc "Returns every element in a tree matching the given attributes."
  @spec all(Element.t() | map(), keyword()) :: [Element.t() | map()]
  def all(tree, selector) when is_list(selector) do
    tree
    |> walk()
    |> Enum.filter(&matches?(&1, selector))
  end

  @doc "Returns the first element matching the given attributes, or nil."
  @spec find(Element.t() | map(), keyword()) :: Element.t() | map() | nil
  def find(tree, selector) when is_list(selector), do: tree |> all(selector) |> List.first()

  @doc "Returns the first matching element or raises."
  @spec find!(Element.t() | map(), keyword()) :: Element.t() | map()
  def find!(tree, selector) when is_list(selector) do
    find(tree, selector) ||
      raise ArgumentError, "no GPUI element matches #{inspect(selector)}"
  end

  defp find_window!(source, predicate, description) do
    Enum.find(snapshot(source).windows, predicate) ||
      raise ArgumentError, "GPUI snapshot has no window with #{description}"
  end

  defp event_window_id(runtime, opts) do
    runtime
    |> window_snapshot(Keyword.get(opts, :window, :first))
    |> Map.fetch!(:id)
  end

  defp walk(%Element{children: children} = element),
    do: [element | Enum.flat_map(children, &walk/1)]

  defp walk(%{type: _type, children: children} = element),
    do: [element | Enum.flat_map(children, &walk/1)]

  defp walk(_primitive), do: []

  defp matches?(%Element{type: type, attrs: attrs}, selector),
    do: matches_attributes?(type, Map.new(attrs), selector)

  defp matches?(%{type: type, attrs: attrs}, selector),
    do: matches_attributes?(type, Map.new(attrs), selector)

  defp matches_attributes?(type, attrs, selector) do
    Enum.all?(selector, fn
      {:type, expected} -> type == expected
      {key, expected} -> Map.get(attrs, key) == expected
    end)
  end
end
