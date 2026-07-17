defmodule GPUI.Codegen.Native.Decoder do
  @moduledoc false

  use RustQ.Meta,
    rust_sources: ["native/gpui/src/nif.rs"]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @spec atom_eq(term(), R.str()) :: boolean()
  defrust atom_eq(term, expected) do
    case term.atom_to_string() do
      {:ok, value} -> value == expected
      {:error, _reason} -> false
    end
  end

  @spec atom_string(term()) :: R.option(String.t())
  defrust atom_string(term) do
    term.atom_to_string().ok()
  end

  @spec number_value(term()) :: R.option(R.f32())
  defrust number_value(term) do
    case decode_as(term, R.f64()) do
      {:ok, value} ->
        some(cast(value, R.f32()))

      {:error, _reason} ->
        case decode_as(term, R.i64()) do
          {:ok, value} -> some(cast(value, R.f32()))
          {:error, _reason} -> nil
        end
    end
  end

  @spec rgb_value(term()) :: R.option(R.u32())
  defrust rgb_value(term) do
    case decode_as(term, {term(), term()}) do
      {:ok, {unit, value}} ->
        if atom_eq(unit, "rgb") do
          decode_as(value, R.u32()).ok()
        else
          nil
        end

      {:error, _reason} ->
        case decode_as(term, R.vec(term())) do
          {:ok, values} ->
            if values.len() == 2 and atom_eq(index(values, 0), "rgb") do
              decode_as(index(values, 1), R.u32()).ok()
            else
              nil
            end

          {:error, _reason} ->
            nil
        end
    end
  end

  @spec px_value(term()) :: R.option(R.f32())
  defrust px_value(term) do
    case decode_as(term, {term(), term()}) do
      {:ok, {unit, value}} ->
        if atom_eq(unit, "px") do
          number_value(value)
        else
          nil
        end

      {:error, _reason} ->
        case decode_as(term, R.vec(term())) do
          {:ok, values} ->
            if values.len() == 2 and atom_eq(index(values, 0), "px") do
              number_value(index(values, 1))
            else
              nil
            end

          {:error, _reason} ->
            nil
        end
    end
  end

  @spec radius_value(term()) :: R.option(R.f32())
  defrust radius_value(term) do
    if atom_eq(term, "full") do
      9999.0
    else
      px_value(term)
    end
  end

  @spec window_id(term()) :: R.nif_result(R.u64())
  defrust window_id(window) do
    decode_as(window.map_get(Atoms.id()), R.u64())
  end

  @spec window_title(term()) :: R.nif_result(String.t())
  defrust window_title(window) do
    decode_as(window.map_get(Atoms.title()), String.t())
  end

  @spec window_size(term()) :: R.nif_result({R.f32(), R.f32()})
  defrust window_size(window) do
    case window.map_get(Atoms.size()) do
      {:ok, size} ->
        case decode_as!(size, R.vec(R.u32())) do
          [width, height] when deref(width) > 0 and deref(height) > 0 ->
            {:ok, {cast(deref(width), R.f32()), cast(deref(height), R.f32())}}

          _other ->
            {:error, badarg()}
        end

      {:error, _missing} ->
        {:ok, {800.0, 600.0}}
    end
  end

  @spec window_tree(term()) :: R.nif_result(R.raw(:ElementNode))
  defrust window_tree(window) do
    root = unwrap!(window.map_get(Atoms.root()))

    case root.map_get(Atoms.tree()) do
      {:ok, tree} -> decode_element_node(tree)
      {:error, _missing} -> {:ok, ElementNode.empty_root()}
    end
  end

  @spec string_attr(term(), atom()) :: R.option(String.t())
  defrust string_attr(term, attr) do
    case term.map_get(Atoms.attrs()) do
      {:ok, attrs} ->
        case attrs.map_get(attr) do
          {:ok, value} -> decode_as(value, String.t()).ok()
          {:error, _missing} -> nil
        end

      {:error, _missing} ->
        nil
    end
  end

  @spec component_string_attr(term(), atom()) :: R.nif_result(R.option(String.t()))
  defrust component_string_attr(term, attr) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

    case attrs.map_get(attr) do
      {:ok, value} -> {:ok, some(decode_as!(value, String.t()))}
      {:error, _missing} -> {:ok, nil}
    end
  end

  @spec component_bool_attr(term(), atom()) :: R.nif_result(R.option(boolean()))
  defrust component_bool_attr(term, attr) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

    case attrs.map_get(attr) do
      {:ok, value} -> {:ok, some(decode_as!(value, boolean()))}
      {:error, _missing} -> {:ok, nil}
    end
  end

  @spec component_number_attr(term(), atom()) :: R.nif_result(R.option(R.f64()))
  defrust component_number_attr(term, attr) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

    case attrs.map_get(attr) do
      {:ok, value} ->
        number =
          case decode_as(value, R.f64()) do
            {:ok, number} -> number
            {:error, _reason} -> cast(decode_as!(value, R.i64()), R.f64())
          end

        if number.is_finite() do
          {:ok, some(number)}
        else
          {:error, badarg()}
        end

      {:error, _missing} ->
        {:ok, nil}
    end
  end

  @spec component_string_list_attr(term(), atom()) :: R.nif_result(R.vec(String.t()))
  defrust component_string_list_attr(term, attr) do
    attrs = unwrap!(term.map_get(Atoms.attrs()))

    case attrs.map_get(attr) do
      {:ok, value} -> {:ok, decode_as!(value, R.vec(String.t()))}
      {:error, _missing} -> {:ok, []}
    end
  end

  @spec component_enum_attr(term(), atom(), R.slice(R.str())) ::
          R.nif_result(R.option(String.t()))
  defrust component_enum_attr(term, attr, allowed) do
    case component_string_attr(term, attr) do
      {:ok, {:some, value}} ->
        if allowed.contains(ref(value.as_str())) do
          {:ok, some(value)}
        else
          {:error, badarg()}
        end

      {:ok, nil} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec component_id(term()) :: R.nif_result(String.t())
  defrust component_id(term) do
    case component_string_attr(term, Atoms.id()) do
      {:ok, {:some, id}} when not id.is_empty() -> {:ok, id}
      _other -> {:error, badarg()}
    end
  end

  @spec text_fragment(term()) :: R.nif_result(String.t())
  defrust text_fragment(term) do
    case decode_as(term, String.t()) do
      {:ok, value} ->
        {:ok, value}

      {:error, _reason} ->
        case decode_as(term, R.i64()) do
          {:ok, value} ->
            {:ok, value.to_string()}

          {:error, _reason} ->
            case decode_as(term, R.f64()) do
              {:ok, value} -> {:ok, value.to_string()}
              {:error, _reason} -> term.atom_to_string()
            end
        end
    end
  end

  def asts do
    Enum.map(MetaAST.functions(__MODULE__), fn ast ->
      %{ast | vis: :crate, attrs: [A.attr(:cfg, feature: "real-gpui") | ast.attrs]}
    end)
  end
end
