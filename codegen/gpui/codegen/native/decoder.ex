defmodule GPUI.Codegen.Native.Decoder do
  @moduledoc "Defines the RustQ decoding helpers shared by generated native schema contracts."

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

  @spec length_value(term()) :: R.option(R.path({:gpui, :DefiniteLength}))
  defrust length_value(term) do
    if atom_eq(term, "full") do
      some(full_length())
    else
      case decode_as(term, {term(), term()}) do
        {:ok, {unit, fraction}} ->
          if atom_eq(unit, "fraction") do
            case number_value(fraction) do
              {:some, value} when value >= 0.0 and value <= 1.0 -> some(fraction_length(value))
              {:some, _other} -> nil
              :none -> nil
            end
          else
            px_length_value(term)
          end

        {:error, _reason} ->
          px_length_value(term)
      end
    end
  end

  @spec px_length_value(term()) :: R.option(R.path({:gpui, :DefiniteLength}))
  defrust px_length_value(term) do
    case px_value(term) do
      {:some, value} -> some(pixel_length(value))
      :none -> nil
    end
  end

  @allow RustQ.Clippy.lint(:manual_map)
  @spec position_length_value(term()) :: R.option(R.path({:gpui, :Length}))
  defrust position_length_value(term) do
    if atom_eq(term, "auto") do
      some(auto_flex_basis())
    else
      case position_definite_length_value(term) do
        {:some, value} -> some(value.into())
        :none -> nil
      end
    end
  end

  @allow RustQ.Clippy.lint(:manual_range_contains)
  @spec position_definite_length_value(term()) ::
          R.option(R.path({:gpui, :DefiniteLength}))
  defrust position_definite_length_value(term) do
    if atom_eq(term, "full") do
      some(full_length())
    else
      case decode_as(term, {term(), term()}) do
        {:ok, {unit, fraction}} ->
          if atom_eq(unit, "fraction") do
            case number_value(fraction) do
              {:some, value} when value >= -1.0 and value <= 1.0 -> some(fraction_length(value))
              {:some, _other} -> nil
              :none -> nil
            end
          else
            px_length_value(term)
          end

        {:error, _reason} ->
          px_length_value(term)
      end
    end
  end

  @spec flex_basis_value(term()) :: R.option(R.path({:gpui, :Length}))
  defrust flex_basis_value(term) do
    if atom_eq(term, "auto") do
      some(auto_flex_basis())
    else
      case length_value(term) do
        {:some, value} -> some(value.into())
        :none -> nil
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

  @spec component_attr(term(), atom()) :: R.nif_result(R.option(term()))
  defrust component_attr(term, attr) do
    case term.map_get(Atoms.attrs()) do
      {:ok, attrs} ->
        case attrs.map_get(attr) do
          {:ok, value} ->
            if atom_eq(value, "nil") do
              {:ok, nil}
            else
              {:ok, some(value)}
            end

          {:error, _missing} ->
            {:ok, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec component_string_attr(term(), atom()) :: R.nif_result(R.option(String.t()))
  defrust component_string_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> {:ok, some(decode_as!(value, String.t()))}
      {:ok, nil} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec component_required_string_attr(term(), atom()) :: R.nif_result(String.t())
  defrust component_required_string_attr(term, attr) do
    case component_string_attr(term, attr) do
      {:ok, {:some, value}} when not value.is_empty() -> {:ok, value}
      _missing_or_empty -> {:error, badarg()}
    end
  end

  @spec component_bool_attr(term(), atom()) :: R.nif_result(R.option(boolean()))
  defrust component_bool_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> {:ok, some(decode_as!(value, boolean()))}
      {:ok, nil} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec component_number_attr(term(), atom()) :: R.nif_result(R.option(R.f64()))
  defrust component_number_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} ->
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

      {:ok, nil} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec component_positive_number_attr(term(), atom()) ::
          R.nif_result(R.option(R.f64()))
  defrust component_positive_number_attr(term, attr) do
    case component_number_attr(term, attr) do
      {:ok, {:some, number}} when number > 0.0 -> {:ok, some(number)}
      {:ok, nil} -> {:ok, nil}
      _invalid -> {:error, badarg()}
    end
  end

  @spec component_non_negative_integer_attr(term(), atom()) ::
          R.nif_result(R.option(R.u64()))
  defrust component_non_negative_integer_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> {:ok, some(decode_as!(value, R.u64()))}
      {:ok, nil} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec component_positive_integer_attr(term(), atom()) ::
          R.nif_result(R.option(R.u64()))
  defrust component_positive_integer_attr(term, attr) do
    case component_non_negative_integer_attr(term, attr) do
      {:ok, {:some, value}} when value > 0 -> {:ok, some(value)}
      {:ok, nil} -> {:ok, nil}
      _invalid -> {:error, badarg()}
    end
  end

  @spec component_optional_number_pair_attr(term(), atom()) ::
          R.nif_result(R.option(R.vec(R.f64())))
  defrust component_optional_number_pair_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} ->
        values = decode_as!(value, R.vec(R.f64()))

        if values.len() == 2 and values.iter().all(fn value -> value.is_finite() end) do
          {:ok, some(values)}
        else
          {:error, badarg()}
        end

      {:ok, nil} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec component_number_pair_attr(term(), atom()) :: R.nif_result(R.vec(R.f64()))
  defrust component_number_pair_attr(term, attr) do
    case component_optional_number_pair_attr(term, attr) do
      {:ok, {:some, values}} -> {:ok, values}
      _missing_or_invalid -> {:error, badarg()}
    end
  end

  @spec component_string_list_attr(term(), atom()) :: R.nif_result(R.vec(String.t()))
  defrust component_string_list_attr(term, attr) do
    case component_attr(term, attr) do
      {:ok, {:some, value}} -> {:ok, decode_as!(value, R.vec(String.t()))}
      {:ok, nil} -> {:ok, []}
      {:error, reason} -> {:error, reason}
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
    component_required_string_attr(term, Atoms.id())
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
      attrs = [A.attr(:cfg, feature: "real-gpui") | ast.attrs]

      attrs =
        case ast.name do
          :length_value ->
            [A.attr(:allow, [A.path([:clippy, :manual_range_contains])]) | attrs]

          name when name in [:px_length_value, :flex_basis_value] ->
            [A.attr(:allow, [A.path([:clippy, :manual_map])]) | attrs]

          _other ->
            attrs
        end

      %{ast | vis: :crate, attrs: attrs}
    end)
  end
end
