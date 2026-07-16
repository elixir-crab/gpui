defmodule GPUI.Codegen.Native.Decoder do
  @moduledoc false

  use RustQ.Meta

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

  @spec px_value(term()) :: R.option(R.f32())
  defrust px_value(term) do
    case decode_as(term, R.vec(term())) do
      {:ok, values} ->
        if values.len() == 2 and atom_eq(index(values, 0), "px") do
          case decode_as(index(values, 1), R.f64()) do
            {:ok, value} -> some(cast(value, R.f32()))
            {:error, _reason} -> nil
          end
        else
          nil
        end

      {:error, _reason} ->
        nil
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
