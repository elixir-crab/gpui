defmodule GPUI.Codegen.Native.EventDefinitions do
  @moduledoc false

  defmacro define_input_kind do
    variants = Enum.map(input_kinds(), &type_variant/1)

    type = variants |> Enum.reverse() |> Enum.reduce(&{:|, [], [&1, &2]})

    quote do
      @type input_kind :: unquote(type)
    end
  end

  @doc false
  def input_kinds do
    GPUI.Schema.components()
    |> Enum.flat_map(&Keyword.keys(&1.events))
    |> Enum.uniq()
    |> Enum.reject(&(&1 == :click))
  end

  defp type_variant(:keydown), do: :key_down
  defp type_variant(:keyup), do: :key_up
  defp type_variant(kind), do: kind
end

defmodule GPUI.Codegen.Native.Events do
  @moduledoc false

  use RustQ.Meta

  alias GPUI.Codegen.Native.EventDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Rust.AST.TypeBuilder, as: T
  alias RustQ.Rust.Identifier
  alias RustQ.Type, as: R

  require EventDefinitions

  @type event_value ::
          R.enum(
            string: [String.t()],
            strings: [R.vec(String.t())],
            boolean: [boolean()],
            number: [R.f64()],
            nil: []
          )

  EventDefinitions.define_input_kind()

  @spec decode_event_value(term()) :: R.option(event_value())
  defrust decode_event_value(term) do
    case decode_as(term, String.t()) do
      {:ok, value} ->
        some(enum_variant(EventValue, :string, value))

      {:error, _reason} ->
        case decode_as(term, R.vec(String.t())) do
          {:ok, value} ->
            some(enum_variant(EventValue, :strings, value))

          {:error, _reason} ->
            case decode_as(term, boolean()) do
              {:ok, value} ->
                some(enum_variant(EventValue, :boolean, value))

              {:error, _reason} ->
                case decode_as(term, R.f64()) do
                  {:ok, value} ->
                    some(enum_variant(EventValue, :number, value))

                  {:error, _reason} ->
                    case decode_as(term, R.i64()) do
                      {:ok, value} ->
                        some(enum_variant(EventValue, :number, cast(value, R.f64())))

                      {:error, _reason} ->
                        case term.atom_to_string() do
                          {:ok, value} ->
                            if value == "nil" do
                              some(enum_variant(EventValue, nil))
                            else
                              nil
                            end

                          {:error, _reason} ->
                            nil
                        end
                    end
                end
            end
        end
    end
  end

  @spec items() :: [AST.item()]
  def items do
    type_items = type_items()
    event_value = find_type!(type_items, :EventValue)
    input_kind = find_type!(type_items, :InputKind)

    [
      configure_enum(event_value, [:Clone, :Debug]),
      event_value_impl(),
      configure_enum(input_kind, [:Clone, :Copy, :Debug]),
      input_kind_impl(input_kinds()),
      rusty_items()
    ]
    |> List.flatten()
  end

  def rusty_items do
    __MODULE__
    |> MetaAST.functions()
    |> Enum.map(&%{&1 | vis: :crate})
  end

  defp type_items, do: __MODULE__.__rustq_type_items__()

  defp find_type!(items, name) do
    Enum.find(items, &match?(%AST.Enum{name: ^name}, &1)) ||
      raise "missing generated Rust enum #{name}"
  end

  defp configure_enum(enum, derive) do
    %{enum | vis: :crate, derive: derive, attrs: [A.attr(:allow, [:dead_code]) | enum.attrs]}
  end

  defp event_value_impl do
    encode = %AST.Function{
      name: :encode,
      lifetimes: [:a],
      args: [A.receiver(), A.arg(:env, T.path(:Env, lifetimes: [:a]))],
      returns: T.path(:Term, lifetimes: [:a]),
      body: [
        A.return_stmt(
          A.match_expr(:self, [
            event_value_arm(:String),
            event_value_arm(:Strings),
            event_value_arm(:Boolean),
            event_value_arm(:Number),
            %AST.Arm{
              pattern: P.path([:Self, :Nil]),
              body: [A.return_stmt(A.method(A.path_call([:atoms, nil]), :encode, [:env]))]
            }
          ])
        )
      ]
    }

    A.impl(:EventValue, items: [encode])
  end

  defp event_value_arm(variant) do
    %AST.Arm{
      pattern: P.path_tuple([:Self, variant], [:value]),
      body: [A.return_stmt(A.method(:value, :encode, [:env]))]
    }
  end

  defp input_kind_impl(kinds) do
    atom_function = %AST.Function{
      name: :atom,
      args: [A.receiver()],
      returns: T.path(:Atom),
      body: [
        A.return_stmt(
          A.match_expr(
            :self,
            Enum.map(kinds, fn kind ->
              %AST.Arm{
                pattern: P.path([:Self, variant(kind)]),
                body: [A.return_stmt(A.path_call([:atoms, kind]))]
              }
            end)
          )
        )
      ]
    }

    A.impl(:InputKind, items: [atom_function])
  end

  defp input_kinds, do: EventDefinitions.input_kinds()

  defp variant(:keydown), do: :KeyDown
  defp variant(:keyup), do: :KeyUp
  defp variant(kind), do: kind |> Atom.to_string() |> Macro.camelize() |> Identifier.atom!()
end
