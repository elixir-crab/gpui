defmodule GPUI.Codegen.Native.ComponentContracts do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type select_option_node :: %{
          required(:label) => String.t(),
          required(:value) => String.t()
        }

  @type radio_option_node :: %{
          required(:label) => String.t(),
          required(:value) => String.t(),
          required(:disabled) => boolean()
        }

  defmacro decode_options(term, opts) do
    disabled? = Keyword.fetch!(opts, :disabled)

    option_statements =
      if disabled? do
        [
          quote do
            disabled =
              case option.map_get(Atoms.disabled()) do
                {:ok, disabled} -> decode_as!(disabled, boolean())
                {:error, _missing} -> false
              end
          end,
          quote do
            accumulate_radio_option(values, decoded_options, label, value, disabled)
          end
        ]
      else
        [quote(do: accumulate_select_option(values, decoded_options, label, value))]
      end

    quote do
      attrs = unwrap!(unquote(term).map_get(Atoms.attrs()))
      options = decode_as!(attrs.map_get(Atoms.options()), R.vec(term()))

      result =
        for option <- options, reduce: {:ok, {HashSet.new(), []}} do
          {:ok, {values, decoded_options}} ->
            label = decode_as!(option.map_get(Atoms.label()), String.t())
            value = decode_as!(option.map_get(Atoms.value()), String.t())
            unquote_splicing(option_statements)

          {:error, reason} ->
            {:error, reason}
        end

      case result do
        {:ok, {_values, decoded}} -> {:ok, decoded}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @allow :unreachable_patterns
  @allow Clippy.redundant_field_names()
  @spec decode_select_options(term()) :: R.nif_result(R.vec(R.path(:SelectOptionNode)))
  defrust decode_select_options(term) do
    decode_options(term, disabled: false)
  end

  @allow :unreachable_patterns
  @allow Clippy.redundant_field_names()
  @spec decode_radio_options(term()) :: R.nif_result(R.vec(R.path(:RadioOptionNode)))
  defrust decode_radio_options(term) do
    decode_options(term, disabled: true)
  end

  @allow Clippy.redundant_field_names()
  @spec accumulate_select_option(
          HashSet.t(String.t()),
          R.vec(R.path(:SelectOptionNode)),
          String.t(),
          String.t()
        ) :: R.nif_result({HashSet.t(String.t()), R.vec(R.path(:SelectOptionNode))})
  defrustp accumulate_select_option(values, options, label, value) do
    if label.is_empty() do
      {:error, badarg()}
    else
      case remember_value(values, value.clone()) do
        {:some, values} ->
          option = struct_literal(SelectOptionNode, label: label, value: value)
          {:ok, {values, append_select_option(options, option)}}

        nil ->
          {:error, badarg()}
      end
    end
  end

  @allow Clippy.redundant_field_names()
  @spec accumulate_radio_option(
          HashSet.t(String.t()),
          R.vec(R.path(:RadioOptionNode)),
          String.t(),
          String.t(),
          boolean()
        ) :: R.nif_result({HashSet.t(String.t()), R.vec(R.path(:RadioOptionNode))})
  defrustp accumulate_radio_option(values, options, label, value, disabled) do
    if label.is_empty() do
      {:error, badarg()}
    else
      case remember_value(values, value.clone()) do
        {:some, values} ->
          option =
            struct_literal(RadioOptionNode,
              label: label,
              value: value,
              disabled: disabled
            )

          {:ok, {values, append_radio_option(options, option)}}

        nil ->
          {:error, badarg()}
      end
    end
  end

  @spec remember_value(HashSet.t(String.t()), String.t()) :: R.option(HashSet.t(String.t()))
  defrustp remember_value(values, value) do
    if value.is_empty() or not values.insert(value) do
      nil
    else
      some(values)
    end
  end

  @spec append_select_option(R.vec(R.path(:SelectOptionNode)), R.path(:SelectOptionNode)) ::
          R.vec(R.path(:SelectOptionNode))
  defrustp append_select_option(options, option) do
    options.push(option)
    options
  end

  @spec append_radio_option(R.vec(R.path(:RadioOptionNode)), R.path(:RadioOptionNode)) ::
          R.vec(R.path(:RadioOptionNode))
  defrustp append_radio_option(options, option) do
    options.push(option)
    options
  end

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    structs =
      MetaAST.struct_type_items(
        __MODULE__,
        [:select_option_node, :radio_option_node],
        derive: [:Clone, :Debug, :Eq, :PartialEq],
        attrs: [A.attr(:cfg, feature: "real-gpui")],
        vis: :crate,
        field_vis: :crate
      )

    functions =
      Enum.map(MetaAST.functions(__MODULE__), fn ast ->
        ast
        |> mark_owned_accumulator_mutable()
        |> then(&%{&1 | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | &1.attrs]})
      end)

    structs ++ functions
  end

  # RustQ rc.3 does not yet infer mutable owned arguments from standard-library
  # methods. Shadow only the accumulator; the behavior remains Rusty-Elixir.
  defp mark_owned_accumulator_mutable(%AST.Function{name: name} = function)
       when name in [:remember_value, :append_select_option, :append_radio_option] do
    accumulator = function.args |> hd() |> Map.fetch!(:name)
    %{function | body: [A.let_mut(accumulator, A.var(accumulator)) | function.body]}
  end

  defp mark_owned_accumulator_mutable(function), do: function
end
