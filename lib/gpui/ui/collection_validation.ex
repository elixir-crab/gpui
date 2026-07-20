defmodule GPUI.UI.CollectionValidation do
  @moduledoc false

  alias GPUI.Element

  def validate_event!(component, assigns, event) do
    value = Map.get(assigns, event) || Map.get(assigns, Atom.to_string(event))

    unless is_binary(value) and value != "" do
      raise ArgumentError, "#{component} requires #{event}"
    end
  end

  def table_children!(children) do
    {columns, rows} = Enum.split_while(children, &match?(%Element{type: :ui_table_column}, &1))

    unless columns != [] and Enum.all?(rows, &match?(%Element{type: :ui_table_row}, &1)) do
      raise ArgumentError,
            "ui_data_table requires table_column children followed by table_row children"
    end

    {columns, rows}
  end

  def element_id!(%Element{attrs: attrs}), do: Map.fetch!(Map.new(attrs), :id)

  def validate_table_columns!(columns, column_ids) do
    if Enum.count_until(columns, 65) > 64 do
      raise ArgumentError, "ui_data_table supports at most 64 columns"
    end

    if column_ids != Enum.uniq(column_ids) do
      raise ArgumentError, "ui_data_table column IDs must be unique"
    end
  end

  def validate_table_rows!(rows, column_count) do
    row_ids = Enum.map(rows, &element_id!/1)

    if row_ids != Enum.uniq(row_ids) do
      raise ArgumentError, "ui_data_table row IDs must be unique"
    end

    unless Enum.all?(rows, &(length(&1.children) == column_count)) do
      raise ArgumentError, "ui_data_table rows must contain one cell child per column"
    end
  end

  def validate_table_selection!(assigns, column_ids) do
    selected_column = Map.get(assigns, :selected_column)

    unless is_nil(selected_column) or selected_column in column_ids do
      raise ArgumentError, "ui_data_table selected_column must identify a table column"
    end
  end

  def validate_table_sort!(assigns, columns, column_ids) do
    sort_column = Map.get(assigns, :sort_column)
    direction = assigns.sort_direction

    sortable_ids =
      columns
      |> Enum.filter(&Map.new(&1.attrs).sortable)
      |> MapSet.new(&element_id!/1)

    cond do
      is_nil(sort_column) and direction == "none" ->
        :ok

      MapSet.member?(sortable_ids, sort_column) and direction in ~w(ascending descending) ->
        :ok

      sort_column in column_ids and direction in ~w(ascending descending) ->
        raise ArgumentError, "ui_data_table sort_column must identify a sortable column"

      true ->
        raise ArgumentError,
              "ui_data_table sort_column and sort_direction must identify an ascending or descending sortable column"
    end

    if MapSet.size(sortable_ids) > 0 do
      validate_event!(:ui_data_table, assigns, :"phx-sort")
    end
  end

  @doc """
  Builds an accessible controlled tree from uniform-height `tree_item/1` children.

  Trees support the same source-backed `total_count`, `offset`, `overscan`,
  selection-index, reveal-index, and `phx-range` contract as `virtual_list/1`.
  Selection emits an item ID through `phx-change`; branch expansion requests
  emit the branch ID through `phx-toggle`.
  """
  def collection_item_ids!(component, item_type, children) do
    item_ids =
      Enum.map(children, fn
        %Element{type: ^item_type, attrs: attrs} ->
          Map.fetch!(Map.new(attrs), :id)

        child ->
          raise ArgumentError,
                "#{component} only accepts #{item_type} children, got: #{inspect(child)}"
      end)

    if item_ids != Enum.uniq(item_ids) do
      raise ArgumentError, "#{component} item IDs must be unique"
    end

    item_ids
  end

  def validate_virtual_collection!(component, assigns, item_ids) do
    validate_collection_label!(component, Map.get(assigns, :label))
    validate_item_height!(component, assigns.item_height)
    validate_reveal_strategy!(component, assigns.reveal_strategy)
    validate_source_range!(component, assigns, item_ids)

    if source_backed_collection?(assigns, item_ids) do
      validate_source_selection!(component, assigns, item_ids, :selected, :selected_index)
      validate_source_selection!(component, assigns, item_ids, :reveal, :reveal_index)
    else
      validate_full_collection!(component, assigns, item_ids)
    end
  end

  defp validate_collection_label!(_component, label) when is_binary(label) and label != "",
    do: :ok

  defp validate_collection_label!(component, _label),
    do: raise(ArgumentError, "#{component} requires a non-empty string label")

  def validate_item_height!(_component, height) when is_number(height) and height > 0, do: :ok

  def validate_item_height!(component, _height),
    do: raise(ArgumentError, "#{component} item_height must be greater than zero")

  defp validate_reveal_strategy!(_component, strategy)
       when strategy in ~w(nearest top center bottom),
       do: :ok

  defp validate_reveal_strategy!(component, _strategy) do
    raise ArgumentError,
          "#{component} reveal_strategy must be nearest, top, center, or bottom"
  end

  defp validate_source_range!(component, assigns, item_ids) do
    validate_non_negative_integer!(component, :total_count, assigns.total_count)
    validate_non_negative_integer!(component, :overscan, assigns.overscan)
    validate_source_offset!(component, assigns.offset, assigns.total_count)
    validate_loaded_count!(component, assigns.offset, length(item_ids), assigns.total_count)

    if source_backed_collection?(assigns, item_ids) do
      validate_event!(component, assigns, :"phx-range")
    end
  end

  def validate_non_negative_integer!(_component, _name, value)
      when is_integer(value) and value >= 0,
      do: :ok

  def validate_non_negative_integer!(component, name, _value),
    do: raise(ArgumentError, "#{component} #{name} must be a non-negative integer")

  defp validate_source_offset!(_component, offset, total_count)
       when is_integer(offset) and offset >= 0 and offset <= total_count,
       do: :ok

  defp validate_source_offset!(component, _offset, _total_count),
    do: raise(ArgumentError, "#{component} offset must be between zero and total_count")

  defp validate_loaded_count!(_component, offset, count, total_count)
       when offset + count <= total_count,
       do: :ok

  defp validate_loaded_count!(component, _offset, _count, _total_count),
    do: raise(ArgumentError, "#{component} loaded slice exceeds total_count")

  defp source_backed_collection?(assigns, item_ids),
    do:
      not is_nil(Map.get(assigns, :"phx-range")) or assigns.offset != 0 or
        assigns.total_count != length(item_ids)

  defp validate_source_selection!(component, assigns, item_ids, value_name, index_name) do
    value = Map.get(assigns, value_name)
    index = Map.get(assigns, index_name)

    validate_source_value!(component, value_name, value)
    validate_source_index!(component, index_name, index, assigns.total_count)
    validate_source_pair!(component, value_name, index_name, value, index)
    validate_loaded_identity!(component, assigns, item_ids, value_name, index_name, value, index)
  end

  defp validate_source_value!(_component, _name, nil), do: :ok

  defp validate_source_value!(_component, _name, value) when is_binary(value) and value != "",
    do: :ok

  defp validate_source_value!(component, name, _value),
    do: raise(ArgumentError, "#{component} #{name} must be a non-empty string")

  defp validate_source_index!(_component, _name, nil, _total_count), do: :ok

  defp validate_source_index!(_component, _name, index, total_count)
       when is_integer(index) and index >= 0 and index < total_count,
       do: :ok

  defp validate_source_index!(component, name, _index, _total_count),
    do: raise(ArgumentError, "#{component} #{name} must identify an index below total_count")

  defp validate_source_pair!(_component, _value_name, _index_name, nil, nil), do: :ok

  defp validate_source_pair!(_component, _value_name, _index_name, value, index)
       when not is_nil(value) and not is_nil(index),
       do: :ok

  defp validate_source_pair!(component, value_name, index_name, _value, _index),
    do:
      raise(
        ArgumentError,
        "#{component} #{value_name} and #{index_name} must be provided together"
      )

  defp validate_loaded_identity!(
         component,
         assigns,
         item_ids,
         value_name,
         index_name,
         value,
         index
       ) do
    loaded? =
      is_integer(index) and index >= assigns.offset and
        index < assigns.offset + length(item_ids)

    if loaded? and Enum.at(item_ids, index - assigns.offset) != value do
      raise ArgumentError,
            "#{component} #{value_name} does not match the loaded item at #{index_name}"
    end
  end

  defp validate_full_collection!(component, assigns, item_ids) do
    if Map.get(assigns, :selected_index) || Map.get(assigns, :reveal_index) do
      raise ArgumentError,
            "#{component} controlled indexes require a source-backed collection with phx-range"
    end

    validate_controlled_item!(component, :selected, Map.get(assigns, :selected), item_ids)
    validate_controlled_item!(component, :reveal, Map.get(assigns, :reveal), item_ids)
  end

  defp validate_controlled_item!(_component, _name, nil, _item_ids), do: :ok

  defp validate_controlled_item!(component, name, value, item_ids) when is_binary(value) do
    if value in item_ids do
      :ok
    else
      raise ArgumentError, "#{component} #{name} must identify a loaded child"
    end
  end

  defp validate_controlled_item!(component, name, _value, _item_ids),
    do: raise(ArgumentError, "#{component} #{name} must identify a loaded child")

  def validate_tree_item!(assigns) do
    validate_tree_item_id!(Map.get(assigns, :id))
    validate_tree_item_flags!(assigns.branch, assigns.expanded, assigns.disabled)
    validate_tree_item_level!(assigns.level)
    validate_tree_parent!(assigns.level, Map.get(assigns, :parent_id))
    validate_tree_expansion!(assigns.branch, assigns.expanded)
    validate_tree_set_position!(Map.get(assigns, :position), Map.get(assigns, :set_size))
  end

  defp validate_tree_item_id!(id) when is_binary(id) and id != "", do: :ok

  defp validate_tree_item_id!(_id),
    do: raise(ArgumentError, "ui_tree_item requires a non-empty string id")

  defp validate_tree_item_flags!(branch, expanded, disabled)
       when is_boolean(branch) and is_boolean(expanded) and is_boolean(disabled),
       do: :ok

  defp validate_tree_item_flags!(_branch, _expanded, _disabled),
    do: raise(ArgumentError, "ui_tree_item branch, expanded, and disabled must be booleans")

  defp validate_tree_item_level!(level) when is_integer(level) and level > 0, do: :ok

  defp validate_tree_item_level!(_level),
    do: raise(ArgumentError, "ui_tree_item level must be a positive integer")

  defp validate_tree_parent!(1, nil), do: :ok

  defp validate_tree_parent!(_level, parent_id) when is_binary(parent_id) and parent_id != "",
    do: :ok

  defp validate_tree_parent!(level, nil) when level > 1,
    do: raise(ArgumentError, "ui_tree_item nested items require a non-empty parent_id")

  defp validate_tree_parent!(_level, _parent_id),
    do: raise(ArgumentError, "ui_tree_item parent_id must be a non-empty string")

  defp validate_tree_expansion!(false, true),
    do: raise(ArgumentError, "ui_tree_item leaves cannot be expanded")

  defp validate_tree_expansion!(_branch, _expanded), do: :ok

  defp validate_tree_set_position!(nil, nil), do: :ok

  defp validate_tree_set_position!(position, set_size)
       when is_integer(position) and is_integer(set_size) and position > 0 and
              position <= set_size,
       do: :ok

  defp validate_tree_set_position!(_position, _set_size),
    do: raise(ArgumentError, "ui_tree_item position and set_size must be valid one-based peers")
end
