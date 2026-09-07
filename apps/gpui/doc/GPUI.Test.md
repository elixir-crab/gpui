# `GPUI.Test`
[🔗](https://github.com/elixir-crab/gpui/blob/v0.2.0-rc.2/lib/gpui/test.ex#L1)

ExUnit helpers for renderer-independent application tests and deterministic
GPUI interaction tests.

Renderer-independent tests use a lightweight `GPUI.Test.Display`:

    use GPUI.Test, async: true

Deterministic tests that need GPUI layout, focus, hit testing, or keyboard
dispatch opt in to a supervised native UI:

    use GPUI.Test, native: [size: {640, 480}]

Native UI cases are skipped by ordinary ExUnit runs. Use the dedicated
deterministic native-test Mix task so the package is compiled for the
`native_test` target.

Both modes import one concise helper vocabulary; the first argument identifies
whether an interaction targets a runtime or an interactive UI.

    defmodule FocusTimerTest do
      use GPUI.Test, async: true

      test "advances from an OTP message" do
        runtime = start_runtime!(FocusTimerApp, args: %{seconds: 2})

        click(runtime, "start")
        send_view(runtime, :tick)
        assert %{remaining: 1, status: :running} = assigns(runtime)
      end
    end

Events are dispatched through `GPUI.Test.Display`, so the same
`GPUI.Runtime` polling boundary used by a real display is exercised without
loading GPUI or requiring desktop libraries.

# `__setup_native__`

```elixir
@spec __setup_native__(
  map(),
  keyword()
) :: {:ok, [{:ui, GPUI.Test.UI.t()}]}
```

Initializes the supervised native UI handle used by `use GPUI.Test, native: ...`.

# `advance`

```elixir
@spec advance(GPUI.Test.UI.t(), non_neg_integer()) :: GPUI.Test.UI.t()
```

Advances GPUI's deterministic clock by the given milliseconds.

# `assigns`

```elixir
@spec assigns(
  GenServer.server() | GPUI.Snapshot.t(),
  :first | pos_integer() | String.t()
) :: map()
```

Returns root-view assigns for a selected window.

# `bounds`

```elixir
@spec bounds(GPUI.Test.UI.t(), String.t()) :: map()
```

Returns the rendered bounds for a stable element ID.

# `change`

```elixir
@spec change(GenServer.server(), String.t(), term(), keyword()) :: GPUI.Snapshot.t()
```

Dispatches a change event and returns the updated snapshot.

# `click`

```elixir
@spec click(GPUI.Test.UI.t(), String.t() | {number(), number()}) :: GPUI.Test.UI.t()
```

Clicks a stable element ID or logical point in an interactive deterministic UI.

# `click`

```elixir
@spec click(GenServer.server(), String.t(), keyword()) :: GPUI.Snapshot.t()
```

Dispatches a click event and returns the updated snapshot.

# `command`

```elixir
@spec command(GenServer.server(), String.t(), keyword()) :: GPUI.Snapshot.t()
```

Dispatches an application command and returns the updated snapshot.

# `copy_selected_line`

```elixir
@spec copy_selected_line(GenServer.server(), String.t(), keyword()) ::
  GPUI.Snapshot.t()
```

Acknowledges deterministic copying of a selected code-viewer line.

# `dispatch`

```elixir
@spec dispatch(GenServer.server(), GPUI.Event.t() | map() | keyword()) ::
  {[map()], GPUI.Snapshot.t()}
```

Dispatches a normalized display event and returns handled events plus the new snapshot.

# `drag`

```elixir
@spec drag(GPUI.Test.UI.t(), {number(), number()}, {number(), number()}) ::
  GPUI.Test.UI.t()
```

Simulates a left-button drag between logical points and settles native work.

# `file_cancel`

```elixir
@spec file_cancel(GenServer.server(), String.t(), keyword()) :: GPUI.Snapshot.t()
```

Cancels a deterministic display-side button file read.

# `file_select`

```elixir
@spec file_select(GenServer.server(), String.t(), String.t(), binary(), keyword()) ::
  GPUI.Snapshot.t()
```

Selects deterministic file bytes for a display-side button file read.

# `focus`

```elixir
@spec focus(GPUI.Test.UI.t(), String.t()) :: GPUI.Test.UI.t()
```

Moves native keyboard focus to a stable element ID.

# `press`

```elixir
@spec press(GPUI.Test.UI.t(), atom() | String.t()) :: GPUI.Test.UI.t()
```

Presses a semantic key in an interactive deterministic UI.

# `range`

```elixir
@spec range(
  GenServer.server(),
  String.t(),
  non_neg_integer(),
  non_neg_integer(),
  keyword()
) ::
  GPUI.Snapshot.t()
```

Delivers a deterministic source-backed virtual-list range request.

# `release`

```elixir
@spec release(GenServer.server(), String.t(), number(), keyword()) ::
  GPUI.Snapshot.t()
```

Dispatches a slider release event and returns the updated snapshot.

# `render`

```elixir
@spec render(module(), map() | keyword()) :: GPUI.Element.t()
```

Renders a view directly with map or keyword assigns.

# `render`

```elixir
@spec render(GPUI.Test.UI.t(), module(), map() | keyword()) :: GPUI.Test.UI.t()
```

Renders a view into an interactive deterministic native UI.

# `resize`

```elixir
@spec resize(
  GPUI.Test.UI.t(),
  {number(), number()}
) :: GPUI.Test.UI.t()
```

Resizes the deterministic native viewport.

# `scroll`

```elixir
@spec scroll(GPUI.Test.UI.t(), String.t(), keyword()) :: GPUI.Test.UI.t()
```

Scrolls a stable target by a bounded logical-pixel delta.

# `search`

```elixir
@spec search(GenServer.server(), String.t(), String.t(), keyword()) ::
  GPUI.Snapshot.t()
```

Dispatches a combobox search event and returns the updated snapshot.

# `select`

```elixir
@spec select(GenServer.server(), String.t(), String.t() | nil, keyword()) ::
  GPUI.Snapshot.t()
```

Selects a controlled form value and returns the updated snapshot.

# `send_view`

```elixir
@spec send_view(GenServer.server(), term(), keyword()) :: GPUI.Snapshot.t()
```

Delivers an OTP message to a root view and returns the updated snapshot.

# `settle`

```elixir
@spec settle(GPUI.Test.UI.t()) :: GPUI.Test.UI.t()
```

Runs native UI work until GPUI is parked.

# `snapshot`

```elixir
@spec snapshot(GenServer.server() | GPUI.Snapshot.t()) :: GPUI.Snapshot.t()
```

Returns the runtime snapshot, or passes an existing snapshot through. Raises on render failure.

# `start_runtime!`

```elixir
@spec start_runtime!(
  module(),
  keyword()
) :: pid()
```

Starts a supervised runtime backed by `GPUI.Test.Display`.

# `submit`

```elixir
@spec submit(GenServer.server(), String.t(), String.t(), keyword()) ::
  GPUI.Snapshot.t()
```

Dispatches an input submission with its current string value.

# `table_cell_select`

```elixir
@spec table_cell_select(
  GenServer.server(),
  String.t(),
  String.t(),
  String.t(),
  keyword()
) :: GPUI.Snapshot.t()
```

Dispatches a deterministic data-table cell selection.

# `table_sort`

```elixir
@spec table_sort(GenServer.server(), String.t(), String.t(), keyword()) ::
  GPUI.Snapshot.t()
```

Dispatches a deterministic sortable data-table header selection.

# `tree`

```elixir
@spec tree(
  GenServer.server() | GPUI.Snapshot.t(),
  :first | pos_integer() | String.t()
) :: map()
```

Returns the rendered tree for a selected window.

# `type`

```elixir
@spec type(GPUI.Test.UI.t(), String.t()) :: GPUI.Test.UI.t()
```

Types text into the focused native input.

# `window_snapshot`

```elixir
@spec window_snapshot(
  GenServer.server() | GPUI.Snapshot.t(),
  :first | pos_integer() | String.t()
) :: map()
```

Returns a window snapshot from a runtime or full snapshot.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
