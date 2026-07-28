defmodule GPUI.Text.Buffer do
  @moduledoc """
  Persistent native Rope text storage with revisioned atomic edits.

  This is a model primitive. It does not represent a file, editor, language,
  gutter, or workspace. Consumers own those policies and may later attach one
  or more renderer primitives to the same buffer.
  """

  alias GPUI.Text.{Edit, Position, Range, Selection, Snapshot, Transaction}

  @enforce_keys [:ref]
  defstruct [:ref]

  @opaque t :: %__MODULE__{ref: reference()}
  @type result(value) :: {:ok, value} | {:error, term()}

  @doc "Creates a native text buffer with one primary selection."
  @spec new(String.t(), keyword()) :: result(t())
  def new(text, opts \\ []) when is_binary(text) and is_list(opts) do
    revision = Keyword.get(opts, :revision, 0)
    selections = Keyword.get(opts, :selections, default_selections())

    with :ok <- validate_revision(revision),
         {:ok, payload} <- selections_payload(selections),
         {:ok, ref} <- GPUI.Native.text_buffer_new(text, revision, payload) do
      {:ok, %__MODULE__{ref: ref}}
    end
  end

  @doc "Returns the current text, revision, selections, and history availability."
  @spec snapshot(t()) :: result(Snapshot.t())
  def snapshot(%__MODULE__{ref: ref}) do
    with {:ok, snapshot} <- GPUI.Native.text_buffer_snapshot(ref) do
      {:ok, decode_snapshot(snapshot)}
    end
  end

  @doc "Atomically applies a transaction based on the current revision."
  @spec transact(t(), Transaction.t()) :: result(map())
  def transact(%__MODULE__{ref: ref}, %Transaction{} = transaction) do
    with {:ok, payload} <- transaction_payload(transaction),
         {:ok, result} <- GPUI.Native.text_buffer_transact(ref, payload) do
      {:ok, %{result | selections: decode_selections(result.selections)}}
    end
  end

  @doc "Undoes one native transaction and creates a new monotonic revision."
  @spec undo(t(), non_neg_integer()) :: result(Snapshot.t())
  def undo(%__MODULE__{ref: ref}, base_revision) do
    with :ok <- validate_revision(base_revision),
         {:ok, snapshot} <- GPUI.Native.text_buffer_undo(ref, base_revision) do
      {:ok, decode_snapshot(snapshot)}
    end
  end

  @doc "Redoes one native transaction and creates a new monotonic revision."
  @spec redo(t(), non_neg_integer()) :: result(Snapshot.t())
  def redo(%__MODULE__{ref: ref}, base_revision) do
    with :ok <- validate_revision(base_revision),
         {:ok, snapshot} <- GPUI.Native.text_buffer_redo(ref, base_revision) do
      {:ok, decode_snapshot(snapshot)}
    end
  end

  defp default_selections do
    position = Position.new(0, 0)

    [
      %Selection{
        id: "primary",
        anchor: position,
        head: position,
        primary: true
      }
    ]
  end

  defp transaction_payload(%Transaction{} = transaction) do
    with :ok <- non_empty_string(transaction.id, :id),
         :ok <- validate_revision(transaction.base_revision),
         {:ok, edits} <- edits_payload(transaction.edits),
         {:ok, selections} <- selections_payload(transaction.selections) do
      {:ok,
       %{
         id: transaction.id,
         base_revision: transaction.base_revision,
         origin: to_string(transaction.origin),
         edits: edits,
         selections: selections
       }}
    end
  end

  defp edits_payload(edits) when is_list(edits) do
    collect(edits, fn
      %Edit{range: %Range{} = range, text: text} when is_binary(text) ->
        with {:ok, range} <- range_payload(range), do: {:ok, %{range: range, text: text}}

      _invalid ->
        {:error, :invalid_edit}
    end)
  end

  defp edits_payload(_invalid), do: {:error, :invalid_edits}

  defp selections_payload(selections) when is_list(selections) do
    collect(selections, fn
      %Selection{id: id, anchor: anchor, head: head, primary: primary}
      when is_binary(id) and id != "" and is_boolean(primary) ->
        with {:ok, anchor} <- position_payload(anchor),
             {:ok, head} <- position_payload(head) do
          {:ok, %{id: id, anchor: anchor, head: head, primary: primary}}
        end

      _invalid ->
        {:error, :invalid_selection}
    end)
  end

  defp selections_payload(_invalid), do: {:error, :invalid_selections}

  defp range_payload(%Range{start: start_position, end: end_position}) do
    with {:ok, start_position} <- position_payload(start_position),
         {:ok, end_position} <- position_payload(end_position) do
      {:ok, %{start: start_position, end: end_position}}
    end
  end

  defp position_payload(%Position{line: line, utf16_offset: utf16_offset})
       when is_integer(line) and line >= 0 and is_integer(utf16_offset) and utf16_offset >= 0,
       do: {:ok, %{line: line, utf16_offset: utf16_offset}}

  defp position_payload(_invalid), do: {:error, :invalid_position}

  defp collect(values, mapper) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, result} ->
      case mapper.(value) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | result]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end)
  end

  defp validate_revision(revision) when is_integer(revision) and revision >= 0, do: :ok
  defp validate_revision(_invalid), do: {:error, :invalid_revision}

  defp non_empty_string(value, _name) when is_binary(value) and value != "", do: :ok
  defp non_empty_string(_value, name), do: {:error, {:invalid_value, name}}

  defp decode_snapshot(snapshot) do
    %Snapshot{
      revision: snapshot.revision,
      text: snapshot.text,
      selections: decode_selections(snapshot.selections),
      can_undo: snapshot.can_undo,
      can_redo: snapshot.can_redo
    }
  end

  defp decode_selections(selections) do
    Enum.map(selections, fn selection ->
      %Selection{
        id: selection.id,
        anchor: decode_position(selection.anchor),
        head: decode_position(selection.head),
        primary: selection.primary
      }
    end)
  end

  defp decode_position(position),
    do: %Position{line: position.line, utf16_offset: position.utf16_offset}
end
