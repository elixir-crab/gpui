defmodule GPUI.Codegen.Native.Event.Definitions do
  @moduledoc "Derives Rust input-kind enums and encoders from schema event declarations."

  defmacro define_input_kind(host) do
    host = Macro.expand(host, __CALLER__)
    variants = Enum.map(input_kinds(host), &type_variant/1)

    type = variants |> Enum.reverse() |> Enum.reduce(&{:|, [], [&1, &2]})

    quote do
      @type input_kind :: unquote(type)
    end
  end

  defmacro define_event_impls(host) do
    host = Macro.expand(host, __CALLER__)

    input_kind_clauses =
      Enum.map(input_kinds(host), fn kind ->
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
  def input_kinds(host) do
    GPUI.Codegen.Native.Host.components(host)
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
