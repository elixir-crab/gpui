defmodule GPUI.Test do
  @moduledoc """
  ExUnit helpers for renderer-independent application tests and deterministic
  GPUI interaction tests.

  Ordinary tests use a lightweight `GPUI.Test.Display`:

      use GPUI.Test, async: true

  Tests that need GPUI layout, focus, hit testing, or keyboard dispatch opt in
  to a supervised deterministic native UI:

      use GPUI.Test, native: [size: {640, 480}]

  Both modes import one concise helper vocabulary; the first argument identifies
  whether an interaction targets a runtime or an interactive UI.

      defmodule FocusTimerTest do
        use GPUI.Test, async: true

        test "advances from an OTP message" do
          runtime = start_gpui!(FocusTimerApp, args: %{seconds: 2})

          click(runtime, "start")
          send_view(runtime, :tick)
          assert %{remaining: 1, status: :running} = assigns(runtime)
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
    {native_opts, case_opts} = Keyword.pop(opts, :native)

    if native_opts && Keyword.get(case_opts, :async, false) do
      raise ArgumentError, "native GPUI tests cannot run asynchronously"
    end

    native_opts =
      case native_opts do
        true ->
          []

        opts when is_list(opts) ->
          opts

        nil ->
          nil

        other ->
          raise ArgumentError,
                "expected :native to be true or a keyword list, got: #{inspect(other)}"
      end

    quote do
      use ExUnit.Case, unquote(case_opts)
      import GPUI.Test

      if unquote(native_opts != nil) do
        @moduletag :native

        setup context do
          GPUI.Test.__setup_native__(context, unquote(Macro.escape(native_opts)))
        end
      end
    end
  end

  @doc false
  @spec __setup_native__(map(), keyword()) :: {:ok, ui: GPUI.Test.UI.t()}
  def __setup_native__(_context, opts) do
    child_spec =
      Supervisor.child_spec(
        {GPUI.Test.Native, Keyword.put(opts, :owner, self())},
        id: {GPUI.Test.Native, make_ref()}
      )

    pid = ExUnit.Callbacks.start_supervised!(child_spec)
    {:ok, ui: GPUI.Test.Native.ui(pid)}
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

  @doc "Renders a view into an interactive deterministic native UI."
  @spec render(GPUI.Test.UI.t(), module(), map() | keyword()) :: GPUI.Test.UI.t()
  def render(%GPUI.Test.UI{} = ui, view, assigns),
    do: GPUI.Test.Native.render(ui, view, assigns)

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
    event =
      case Event.normalize(event) do
        {:ok, event} -> event
        {:error, reason} -> raise ArgumentError, "invalid GPUI test event: #{inspect(reason)}"
      end

    with {:ok, :ok} <- Runtime.inject_event(runtime, event),
         handled when is_list(handled) <- Runtime.drain_events(runtime) do
      {handled, Runtime.snapshot(runtime)}
    else
      {:error, reason} -> raise "GPUI test display failed to process event: #{inspect(reason)}"
    end
  end

  @doc "Delivers an OTP message to a root view and returns the updated snapshot."
  @spec send_view(GenServer.server(), term(), keyword()) :: Snapshot.t()
  def send_view(runtime, message, opts \\ []) do
    window_id = event_window_id(runtime, opts)
    {:ok, snapshot} = Runtime.send_view(runtime, window_id, message)
    snapshot
  end

  @doc "Dispatches an application command and returns the updated snapshot."
  @spec command(GenServer.server(), String.t(), keyword()) :: Snapshot.t()
  def command(runtime, event, opts \\ []),
    do: dispatch_named(runtime, :command, event, opts)

  @doc "Clicks a stable element ID or logical point in an interactive deterministic UI."
  @spec click(GPUI.Test.UI.t(), String.t() | {number(), number()}) :: GPUI.Test.UI.t()
  def click(%GPUI.Test.UI{} = ui, target), do: GPUI.Test.Native.click(ui, target)

  @doc "Scrolls a stable target by a bounded logical-pixel delta."
  @spec scroll(GPUI.Test.UI.t(), String.t(), keyword()) :: GPUI.Test.UI.t()
  def scroll(%GPUI.Test.UI{} = ui, target, opts),
    do: GPUI.Test.Native.scroll(ui, target, opts)

  @doc "Types text into the focused native input."
  @spec type(GPUI.Test.UI.t(), String.t()) :: GPUI.Test.UI.t()
  def type(%GPUI.Test.UI{} = ui, text), do: GPUI.Test.Native.type(ui, text)

  @doc "Resizes the deterministic native viewport."
  @spec resize(GPUI.Test.UI.t(), {number(), number()}) :: GPUI.Test.UI.t()
  def resize(%GPUI.Test.UI{} = ui, size), do: GPUI.Test.Native.resize(ui, size)

  @doc "Moves native keyboard focus to a stable element ID."
  @spec focus(GPUI.Test.UI.t(), String.t()) :: GPUI.Test.UI.t()
  def focus(%GPUI.Test.UI{} = ui, target), do: GPUI.Test.Native.focus(ui, target)

  @doc "Presses a semantic key in an interactive deterministic UI."
  @spec press(GPUI.Test.UI.t(), atom() | String.t()) :: GPUI.Test.UI.t()
  def press(%GPUI.Test.UI{} = ui, key), do: GPUI.Test.Native.press(ui, key)

  @doc "Returns the rendered bounds for a stable element ID."
  @spec bounds(GPUI.Test.UI.t(), String.t()) :: map()
  def bounds(%GPUI.Test.UI{} = ui, target), do: GPUI.Test.Native.bounds(ui, target)

  @doc "Runs native UI work until GPUI is parked."
  @spec settle(GPUI.Test.UI.t()) :: GPUI.Test.UI.t()
  def settle(%GPUI.Test.UI{} = ui), do: GPUI.Test.Native.settle(ui)

  @doc "Advances GPUI's deterministic clock by the given milliseconds."
  @spec advance(GPUI.Test.UI.t(), non_neg_integer()) :: GPUI.Test.UI.t()
  def advance(%GPUI.Test.UI{} = ui, milliseconds),
    do: GPUI.Test.Native.advance(ui, milliseconds)

  @doc "Dispatches a click event and returns the updated snapshot."
  @spec click(GenServer.server(), String.t(), keyword()) :: Snapshot.t()
  def click(runtime, event, opts \\ []),
    do: dispatch_named(runtime, :click, event, opts)

  @doc "Dispatches a change event and returns the updated snapshot."
  @spec change(GenServer.server(), String.t(), term(), keyword()) :: Snapshot.t()
  def change(runtime, event, value, opts \\ []),
    do: dispatch_value(runtime, :change, event, value, opts)

  @doc "Dispatches an input submission with its current string value."
  @spec submit(GenServer.server(), String.t(), String.t(), keyword()) :: Snapshot.t()
  def submit(runtime, event, value, opts \\ []) when is_binary(value),
    do: dispatch_value(runtime, :submit, event, value, opts)

  @doc "Delivers a deterministic source-backed virtual-list range request."
  @spec range(GenServer.server(), String.t(), non_neg_integer(), non_neg_integer(), keyword()) ::
          Snapshot.t()
  def range(runtime, event, first, last, opts \\ [])
      when is_integer(first) and first >= 0 and is_integer(last) and last >= first do
    dispatch_value(runtime, :range, event, %{first: first, last: last}, opts)
  end

  @doc "Dispatches a deterministic sortable data-table header selection."
  @spec table_sort(GenServer.server(), String.t(), String.t(), keyword()) :: Snapshot.t()
  def table_sort(runtime, event, column_id, opts \\ [])
      when is_binary(column_id) and column_id != "",
      do: change(runtime, event, column_id, opts)

  @doc "Dispatches a deterministic data-table cell selection."
  @spec table_cell_select(
          GenServer.server(),
          String.t(),
          String.t(),
          String.t(),
          keyword()
        ) :: Snapshot.t()
  def table_cell_select(runtime, event, row_id, column_id, opts \\ [])
      when is_binary(row_id) and row_id != "" and is_binary(column_id) and column_id != "",
      do: change(runtime, event, [row_id, column_id], opts)

  @doc "Acknowledges deterministic copying of a selected code-viewer line."
  @spec copy_selected_line(GenServer.server(), String.t(), keyword()) :: Snapshot.t()
  def copy_selected_line(runtime, event, opts \\ []),
    do: dispatch_named(runtime, :copy, event, opts)

  @doc "Selects deterministic file bytes for a display-side button file read."
  @spec file_select(GenServer.server(), String.t(), String.t(), binary(), keyword()) ::
          Snapshot.t()
  def file_select(runtime, event, name, data, opts \\ [])
      when is_binary(name) and name != "" and is_binary(data) do
    dispatch_value(
      runtime,
      :file_read,
      event,
      %{operation_id: 0, status: :selected, name: name, size: byte_size(data), data: data},
      opts
    )
  end

  @doc "Cancels a deterministic display-side button file read."
  @spec file_cancel(GenServer.server(), String.t(), keyword()) :: Snapshot.t()
  def file_cancel(runtime, event, opts \\ []),
    do: dispatch_value(runtime, :file_read, event, %{operation_id: 0, status: :cancelled}, opts)

  @doc "Toggles a controlled boolean component and returns the updated snapshot."
  @spec toggle(GenServer.server(), String.t(), boolean(), keyword()) :: Snapshot.t()
  def toggle(runtime, event, checked, opts \\ []), do: change(runtime, event, checked, opts)

  @doc "Selects a controlled form value and returns the updated snapshot."
  @spec select(GenServer.server(), String.t(), String.t() | nil, keyword()) :: Snapshot.t()
  def select(runtime, event, value, opts \\ []), do: change(runtime, event, value, opts)

  @doc "Dispatches a slider release event and returns the updated snapshot."
  @spec release(GenServer.server(), String.t(), number(), keyword()) :: Snapshot.t()
  def release(runtime, event, value, opts \\ []),
    do: dispatch_value(runtime, :release, event, value, opts)

  @doc "Dispatches a combobox search event and returns the updated snapshot."
  @spec search(GenServer.server(), String.t(), String.t(), keyword()) :: Snapshot.t()
  def search(runtime, event, query, opts \\ []),
    do: dispatch_value(runtime, :search, event, query, opts)

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

  defp dispatch_named(runtime, type, event, opts) do
    {_handled, snapshot} =
      dispatch(runtime, %{
        type: type,
        window_id: event_window_id(runtime, opts),
        event: event
      })

    snapshot
  end

  defp dispatch_value(runtime, type, event, value, opts) do
    {_handled, snapshot} =
      dispatch(runtime, %{
        type: type,
        window_id: event_window_id(runtime, opts),
        event: event,
        value: value
      })

    snapshot
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
