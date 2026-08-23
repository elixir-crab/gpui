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

  use RustQ.Meta,
    rust_sources: ["native/gpui/src/event.rs"]

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

  @spec encode_bounds_event(
          R.path(:Env, R.lifetime(:a)),
          R.u64(),
          String.t(),
          R.path(:ElementBoundsGeometry)
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_bounds_event(env, window_id, event, value),
    do: encode_value_event(env, Atoms.bounds(), window_id, event, value.encode(env))

  @spec encode_clipboard_event(
          R.path(:Env, R.lifetime(:a)),
          R.u64(),
          String.t(),
          R.path(:TransferPayload)
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_clipboard_event(env, window_id, event, value),
    do: encode_value_event(env, Atoms.clipboard(), window_id, event, value.encode(env))

  @spec encode_transfer_event(
          R.path(:Env, R.lifetime(:a)),
          R.ref(input_kind()),
          R.u64(),
          String.t(),
          R.path(:TransferEventValue)
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_transfer_event(env, kind, window_id, event, value),
    do: encode_value_event(env, kind.atom(), window_id, event, value.encode(env))

  @allow :dead_code
  @spec encode_value_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.path(:Term, R.lifetime(:a))
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrustp encode_value_event(env, kind, window_id, event, value) do
    encode_event_map(
      env,
      [
        {Atoms.type_atom(), kind.to_term(env)},
        {Atoms.window_id(), window_id.encode(env)},
        {Atoms.event(), event.encode(env)},
        {Atoms.value(), value}
      ]
    )
  end

  @spec encode_focus_event(
          R.path(:Env, R.lifetime(:a)),
          R.ref(input_kind()),
          R.u64(),
          String.t(),
          String.t()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_focus_event(env, kind, window_id, event, id) do
    value = encode_event_map(env, [{Atoms.id(), id.encode(env)}])
    encode_value_event(env, kind.atom(), window_id, event, value)
  end

  @spec encode_virtual_range_event(
          R.path(:Env, R.lifetime(:a)),
          R.u64(),
          String.t(),
          R.u64(),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_virtual_range_event(env, window_id, event, first, last) do
    value =
      encode_event_map(
        env,
        [
          {Atoms.first(), first.encode(env)},
          {Atoms.last(), last.encode(env)}
        ]
      )

    encode_value_event(env, Atoms.range(), window_id, event, value)
  end

  @spec encode_missing_resource_event(
          R.path(:Env, R.lifetime(:a)),
          R.u64(),
          String.t()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_missing_resource_event(env, window_id, id) do
    encode_event_map(
      env,
      [
        {Atoms.type_atom(), Atoms.missing_resource().to_term(env)},
        {Atoms.window_id(), window_id.encode(env)},
        {Atoms.id(), id.encode(env)},
        {Atoms.resource_type(), Atoms.raster().to_term(env)}
      ]
    )
  end

  @spec encode_revisioned_transaction_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.path(:TextTransaction),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_revisioned_transaction_event(env, kind, window_id, event, value, revision),
    do: encode_revisioned_event(env, kind, window_id, event, value.encode(env), revision)

  @spec encode_revisioned_selection_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.vec(R.path(:TextSelection)),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_revisioned_selection_event(env, kind, window_id, event, value, revision),
    do: encode_revisioned_event(env, kind, window_id, event, value.encode(env), revision)

  @spec encode_revisioned_viewport_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.path(:TextViewportGeometry),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_revisioned_viewport_event(env, kind, window_id, event, value, revision),
    do: encode_revisioned_event(env, kind, window_id, event, value.encode(env), revision)

  @spec encode_revisioned_geometry_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.path(:TextCaretGeometry),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_revisioned_geometry_event(env, kind, window_id, event, value, revision),
    do: encode_revisioned_event(env, kind, window_id, event, value.encode(env), revision)

  @spec encode_revisioned_range_geometry_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.vec(R.path(:TextRangeGeometry)),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_revisioned_range_geometry_event(env, kind, window_id, event, value, revision),
    do: encode_revisioned_event(env, kind, window_id, event, value.encode(env), revision)

  @spec encode_revisioned_position_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.path(:TextPosition),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_revisioned_position_event(env, kind, window_id, event, value, revision),
    do: encode_revisioned_event(env, kind, window_id, event, value.encode(env), revision)

  @spec encode_revisioned_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t(),
          R.path(:Term, R.lifetime(:a)),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrustp encode_revisioned_event(env, kind, window_id, event, value, revision) do
    encode_event_map(
      env,
      [
        {Atoms.type_atom(), kind.to_term(env)},
        {Atoms.window_id(), window_id.encode(env)},
        {Atoms.event(), event.encode(env)},
        {Atoms.value(), value},
        {Atoms.revision(), revision.encode(env)}
      ]
    )
  end

  @spec encode_input_event(
          R.path(:Env, R.lifetime(:a)),
          R.ref(input_kind()),
          R.u64(),
          String.t(),
          R.option(event_value())
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_input_event(env, kind, window_id, event, value) do
    entries = [
      {Atoms.type_atom(), kind.atom().to_term(env)},
      {Atoms.window_id(), window_id.encode(env)},
      {Atoms.event(), event.encode(env)}
    ]

    entries =
      case value do
        nil -> entries
        {:some, value} -> append_event_value(entries, env, value)
      end

    encode_event_map(env, entries)
  end

  @spec append_event_value(
          R.vec({R.path(:Atom), R.path(:Term, R.lifetime(:a))}),
          R.path(:Env, R.lifetime(:a)),
          event_value()
        ) :: R.vec({R.path(:Atom), R.path(:Term, R.lifetime(:a))})
  defrustp append_event_value(entries, env, value) do
    entries.push({Atoms.value(), value.encode(env)})
    entries
  end

  @spec encode_named_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64(),
          String.t()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_named_event(env, kind, window_id, event) do
    encode_event_map(
      env,
      [
        {Atoms.type_atom(), kind.to_term(env)},
        {Atoms.window_id(), window_id.encode(env)},
        {Atoms.event(), event.encode(env)}
      ]
    )
  end

  @spec encode_window_event(
          R.path(:Env, R.lifetime(:a)),
          R.path(:Atom),
          R.u64()
        ) :: R.nif_result(R.path(:Term, R.lifetime(:a)))
  defrust encode_window_event(env, kind, window_id) do
    encode_event_map(
      env,
      [
        {Atoms.type_atom(), kind.to_term(env)},
        {Atoms.window_id(), window_id.encode(env)}
      ]
    )
  end

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
    always = [
      :decode_event_value,
      :encode_input_event,
      :append_event_value,
      :encode_named_event,
      :encode_window_event,
      :encode_value_event
    ]

    real_gpui_only = [
      :encode_bounds_event,
      :encode_focus_event,
      :encode_missing_resource_event
    ]

    component_only = [
      :encode_clipboard_event,
      :encode_transfer_event,
      :encode_virtual_range_event,
      :encode_revisioned_transaction_event,
      :encode_revisioned_selection_event,
      :encode_revisioned_viewport_event,
      :encode_revisioned_geometry_event,
      :encode_revisioned_range_geometry_event,
      :encode_revisioned_position_event,
      :encode_revisioned_event
    ]

    (Enum.map(always, &MetaAST.function!(__MODULE__, &1)) ++
       configured_functions(real_gpui_only, "real-gpui") ++
       configured_functions(component_only, "components"))
    |> Enum.uniq_by(& &1.name)
    |> Enum.map(&%{&1 | vis: :crate})
  end

  defp configured_functions(names, feature) do
    Enum.map(names, fn name ->
      function = MetaAST.function!(__MODULE__, name)
      %{function | attrs: [A.attr(:cfg, feature: feature) | function.attrs]}
    end)
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
