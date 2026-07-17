defmodule GPUI.Codegen.Native.Resources do
  @moduledoc false

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.TypeBuilder, as: T

  @spec items() :: [AST.item()]
  def items do
    Enum.flat_map(GPUI.Schema.resource_specs(), fn resource ->
      [resource_struct(resource), resource_decoder(resource)]
    end)
  end

  defp resource_struct(resource) do
    %AST.Struct{
      name: resource_struct_name(resource),
      vis: :crate,
      derive: [:Clone, :Debug, :Default],
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      fields:
        Enum.map(resource.fields, fn {name, type} ->
          %AST.StructField{name: name, type: rust_type(type), vis: :crate}
        end)
    }
  end

  defp resource_decoder(resource) do
    %AST.Function{
      name: resource_decoder_name(resource),
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [A.arg(:term, T.path(:Term))],
      returns: T.nif_result(resource_struct_name(resource)),
      body: [
        A.return_stmt(
          A.ok(
            A.struct_expr(
              resource_struct_name(resource),
              Enum.map(resource.fields, fn {name, type} ->
                {name, decode_field(name, type)}
              end)
            )
          )
        )
      ]
    }
  end

  defp rust_type(:u32), do: T.path(:u32)
  defp rust_type(:string), do: T.path(:String)
  defp rust_type(:atom), do: T.path(:String)
  defp rust_type(:binary), do: T.vec(:u8)
  defp rust_type({:field, _source, type}), do: rust_type(type)
  defp rust_type({:option, type}), do: T.option(rust_type(type))
  defp rust_type({:default, :atom_string, _default}), do: T.path(:String)

  defp decode_field(name, :u32), do: decode_required(name, :u32)
  defp decode_field(name, :string), do: decode_required(name, :string)

  defp decode_field(name, :atom) do
    name
    |> map_get()
    |> A.try()
    |> A.method(:atom_to_string)
    |> A.try()
  end

  defp decode_field(_name, {:field, source, type}), do: decode_field(source, type)

  defp decode_field(name, :binary) do
    name
    |> map_get()
    |> A.try()
    |> A.method(:decode, [], generics: [:Binary])
    |> A.try()
    |> A.method(:as_slice)
    |> A.method(:to_vec)
  end

  defp decode_field(name, {:option, type}) do
    name
    |> map_get()
    |> A.method(:ok)
    |> A.method(:and_then, [
      A.closure(
        [:value],
        A.method(A.method(:value, :decode, [], generics: [rust_type(type)]), :ok)
      )
    ])
  end

  defp decode_field(name, {:default, :atom_string, default}) do
    name
    |> map_get()
    |> A.try()
    |> A.method(:atom_to_string)
    |> A.method(:unwrap_or_else, [
      A.closure([:_], A.method(A.lit(default), :to_string))
    ])
  end

  defp decode_required(name, type) do
    name
    |> map_get()
    |> A.try()
    |> A.method(:decode, [], generics: [rust_type(type)])
    |> A.try()
  end

  defp resource_struct_name(%{name: :raster}), do: :RasterData
  defp resource_struct_name(%{name: :resource_ref}), do: :ResourceRefData

  defp resource_decoder_name(%{name: :raster}), do: :decode_raster_resource
  defp resource_decoder_name(%{name: :resource_ref}), do: :decode_resource_ref_data

  defp map_get(name),
    do: A.method(:term, :map_get, [A.path_call([:atoms, atom_name(name)])])

  defp atom_name(:type), do: :type_atom
  defp atom_name(name), do: name
end
