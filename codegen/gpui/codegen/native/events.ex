defmodule GPUI.Codegen.Native.EventDefinitions do
  @moduledoc "Derives Rust input-kind enums and encoders from schema event declarations."

  defmacro define_input_kind do
    variants = Enum.map(input_kinds(), &type_variant/1)

    type = variants |> Enum.reverse() |> Enum.reduce(&{:|, [], [&1, &2]})

    quote do
      @type input_kind :: unquote(type)
    end
  end

  defmacro define_event_impls do
    input_kind_clauses =
      Enum.map(input_kinds(), fn kind ->
        variant = type_variant(kind)
        atom_call = remote_call(:Atoms, kind)

        {:->, [], [[quote(do: enum_variant(Self, unquote(variant)))], atom_call]}
      end)

    quote do
      defrustimpl EventValue do
        @spec encode(
                R.ref(event_value()),
                R.path(:Env, R.lifetime(:a))
              ) :: R.path(:Term, R.lifetime(:a))
        defrust encode(self, env) do
          case self do
            enum_variant(Self, :string, value) -> value.encode(env)
            enum_variant(Self, :strings, value) -> value.encode(env)
            enum_variant(Self, :numbers, value) -> value.encode(env)
            enum_variant(Self, :boolean, value) -> value.encode(env)
            enum_variant(Self, :number, value) -> value.encode(env)
            enum_variant(Self, nil) -> Atoms.nil().encode(env)
          end
        end
      end

      defrustimpl InputKind do
        @spec atom(R.ref(input_kind())) :: R.path(:Atom)
        defrust atom(self) do
          case self do
            (unquote_splicing(input_kind_clauses))
          end
        end
      end
    end
  end

  @doc "Returns the unique non-click input kinds declared by the component schema."
  def input_kinds do
    GPUI.Schema.components()
    |> Enum.flat_map(&Keyword.keys(&1.events))
    |> Enum.uniq()
    |> Enum.reject(&(&1 == :click))
  end

  defp remote_call(module, function) do
    module = {:__aliases__, [], [module]}
    {{:., [], [module, function]}, [], []}
  end

  defp type_variant(:keydown), do: :key_down
  defp type_variant(:keyup), do: :key_up
  defp type_variant(kind), do: kind
end

defmodule GPUI.Codegen.Native.Events do
  @moduledoc "Emits generated native event-value decoding and input-kind contracts."

  use RustQ.Meta

  alias GPUI.Codegen.Native.EventDefinitions
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  require EventDefinitions

  @type event_value ::
          R.enum(
            string: [String.t()],
            strings: [R.vec(String.t())],
            numbers: [R.vec(R.f64())],
            boolean: [boolean()],
            number: [R.f64()],
            nil: []
          )

  EventDefinitions.define_input_kind()
  EventDefinitions.define_event_impls()

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
            case decode_as(term, R.vec(R.f64())) do
              {:ok, value} ->
                some(enum_variant(EventValue, :numbers, value))

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
  end

  @spec items() :: [AST.item()]
  def items do
    type_items = type_items()
    event_value = find_type!(type_items, :EventValue)
    input_kind = find_type!(type_items, :InputKind)

    [
      configure_enum(event_value, [:Clone, :Debug]),
      impl_item!(:EventValue),
      configure_enum(input_kind, [:Clone, :Copy, :Debug]),
      impl_item!(:InputKind),
      rusty_items()
    ]
    |> List.flatten()
  end

  def rusty_items do
    [MetaAST.function!(__MODULE__, :decode_event_value)]
    |> Enum.map(&%{&1 | vis: :crate})
  end

  defp type_items, do: MetaAST.generated_type_items(__MODULE__)

  defp find_type!(items, name) do
    Enum.find(items, &match?(%AST.Enum{name: ^name}, &1)) ||
      raise "missing generated Rust enum #{name}"
  end

  defp configure_enum(enum, derive) do
    %{enum | vis: :crate, derive: derive, attrs: [A.attr(:allow, [:dead_code]) | enum.attrs]}
  end

  defp impl_item!(target), do: MetaAST.impl!(__MODULE__, target)
end
