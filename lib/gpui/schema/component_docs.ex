defmodule GPUI.Schema.ComponentDocs do
  @moduledoc "Schema-driven generation of component option tables and typespecs."

  alias GPUI.Schema.Component

  @doc "Renders the generated options table for one component schema."
  @spec options_doc(Component.t()) :: String.t()
  def options_doc(%Component{} = component) do
    rows =
      component
      |> option_rows()
      |> Enum.map_join("\n", fn {name, type, required?, default} ->
        "| `#{option_name(name)}` | #{type_doc(type)} | #{required_doc(required?)} | #{default_doc(default)} |"
      end)

    """

    ## Options

    | Option | Type | Required | Default |
    | --- | --- | :---: | --- |
    #{rows}
    """
  end

  @doc "Builds the public options typespec AST for one component schema."
  @spec option_type_ast(Component.t()) :: Macro.t()
  def option_type_ast(%Component{} = component) do
    entries =
      Enum.map(option_rows(component), fn {name, type, required?, _default} ->
        key_kind = if required?, do: :required, else: :optional
        {{key_kind, [], [name]}, type_ast(type)}
      end)

    {:%{}, [], entries}
  end

  defp option_rows(component) do
    attrs =
      component.attrs
      |> Enum.reject(fn {name, _type} -> name in component.public_hidden_attrs end)
      |> Enum.map(fn {name, type} ->
        required? = required_attr?(component, name, type)
        {name, type, required?, if(required?, do: :none, else: default(type))}
      end)

    events =
      Enum.map(component.events, fn {_event, name} ->
        {name, :event, name in component.required_events, :none}
      end)

    slots =
      Enum.map(component.public_slots, fn {name, cardinality} ->
        {name, {:slot, cardinality}, cardinality in [:required, :one_or_more], :none}
      end)

    common =
      [
        {:class, :class, false, :none},
        {:style, :style, false, :none}
      ] ++
        if component.children and component.public_slots == [] do
          [{:children, :children, false, {:value, []}}]
        else
          []
        end

    attrs ++ events ++ slots ++ common
  end

  defp required_attr?(_component, :id, _type), do: true

  defp required_attr?(component, name, type),
    do: name in component.public_required_attrs or unwrap_default(type) == :required_string

  defp unwrap_default({:default, type}), do: type
  defp unwrap_default({:default, type, _value}), do: type
  defp unwrap_default(type), do: type

  defp default({:default, _type, value}), do: {:value, value}
  defp default({:default, type}), do: scalar_default(type)
  defp default(:boolean), do: {:value, false}
  defp default(:string_list), do: {:value, []}
  defp default(_type), do: :none

  defp scalar_default(:string), do: {:value, ""}
  defp scalar_default(:number), do: {:value, 0.0}
  defp scalar_default(:positive_number), do: :none
  defp scalar_default(:non_negative_integer), do: {:value, 0}
  defp scalar_default(:positive_integer), do: :none
  defp scalar_default(:boolean), do: {:value, false}
  defp scalar_default(:string_list), do: {:value, []}
  defp scalar_default(_type), do: :none

  defp option_name(name), do: inspect(name)

  defp type_doc({:default, type}), do: type_doc(type)
  defp type_doc({:default, type, _value}), do: type_doc(type)
  defp type_doc(:string), do: "`String.t()`"
  defp type_doc(:required_string), do: "non-empty `String.t()`"
  defp type_doc(:number), do: "`number()`"
  defp type_doc(:positive_number), do: "positive `number()`"
  defp type_doc(:unit_number), do: "`number()` from zero through one"
  defp type_doc(:edge_fade_size), do: "`number()` from 1 through 256"
  defp type_doc(:non_negative_integer), do: "`non_neg_integer()`"
  defp type_doc(:positive_integer), do: "`pos_integer()`"
  defp type_doc(:boolean), do: "`boolean()`"
  defp type_doc(:string_list), do: "list of `String.t()`"
  defp type_doc(:number_pair), do: "two-element list of `number()`"
  defp type_doc(:select_options), do: "list of `t:GPUI.UI.select_option/0`"
  defp type_doc(:radio_options), do: "list of `t:GPUI.UI.radio_option/0`"
  defp type_doc(:rich_text_runs), do: "list of `t:GPUI.Text.RichRun.t/0`"
  defp type_doc(:resource), do: "resource map"

  defp type_doc({:enum, values}) do
    Enum.map_join(values, ", ", &"`#{inspect(&1)}`")
  end

  defp type_doc({:enum_list, values}) do
    "unique list of #{type_doc({:enum, values})}"
  end

  defp type_doc(:event), do: "non-empty event name"
  defp type_doc({:slot, :required}), do: "one named slot"
  defp type_doc({:slot, :optional}), do: "zero or one named slot"
  defp type_doc({:slot, :one_or_more}), do: "one or more named slots"
  defp type_doc(:class), do: "`String.t()`"
  defp type_doc(:style), do: "`keyword()` or `map()`"
  defp type_doc(:children), do: "list of `t:GPUI.Element.child/0`"

  defp required_doc(true), do: "yes"
  defp required_doc(false), do: "no"

  defp default_doc(:none), do: "—"
  defp default_doc({:value, value}), do: "`#{inspect(value)}`"

  defp type_ast({:default, type}), do: type_ast(type)
  defp type_ast({:default, type, _value}), do: type_ast(type)
  defp type_ast(type) when type in [:string, :required_string], do: quote(do: String.t())

  defp type_ast(type)
       when type in [:number, :positive_number, :unit_number, :edge_fade_size],
       do: quote(do: number())

  defp type_ast(:non_negative_integer), do: quote(do: non_neg_integer())
  defp type_ast(:positive_integer), do: quote(do: pos_integer())
  defp type_ast(:boolean), do: quote(do: boolean())
  defp type_ast(:string_list), do: quote(do: [String.t()])
  defp type_ast(:number_pair), do: quote(do: [number()])

  defp type_ast(:select_options), do: quote(do: [GPUI.UI.select_option()])
  defp type_ast(:radio_options), do: quote(do: [GPUI.UI.radio_option()])
  defp type_ast(:rich_text_runs), do: quote(do: [GPUI.Text.RichRun.t()])
  defp type_ast(:resource), do: quote(do: map())
  defp type_ast({:enum, _values}), do: quote(do: String.t())
  defp type_ast({:enum_list, _values}), do: quote(do: [String.t() | atom()])
  defp type_ast(:event), do: quote(do: String.t())
  defp type_ast({:slot, _cardinality}), do: quote(do: [GPUI.UI.Overlay.slot()])
  defp type_ast(:class), do: quote(do: String.t())
  defp type_ast(:style), do: quote(do: keyword() | map())
  defp type_ast(:children), do: quote(do: [GPUI.Element.child()])
end
