defmodule GPUI.Codegen.Native.Style do
  @moduledoc false

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Rust.AST.TypeBuilder, as: T

  @spec source([GPUI.Schema.Style.t()]) :: String.t()
  def source(style_specs) do
    [
      generated_style_struct(style_specs),
      generated_apply_style_function(style_specs),
      generated_apply_render_style_function(style_specs)
    ]
    |> Enum.join("\n\n")
  end

  defp generated_style_struct(style_specs) do
    %AST.Struct{
      name: :StyleAttrs,
      vis: :crate,
      derive: [:Clone, :Debug, :Default],
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      fields:
        Enum.map(style_specs, fn spec ->
          %AST.StructField{name: spec.field, type: rust_style_type(spec.type), vis: :crate}
        end)
    }
    |> render_item()
  end

  defp rust_style_type({:atom_eq, _expected}), do: T.path(:bool)
  defp rust_style_type(:atom_string), do: %AST.TypeOption{inner: T.path(:String)}
  defp rust_style_type(:rgb), do: %AST.TypeOption{inner: T.path(:u32)}
  defp rust_style_type(:number), do: %AST.TypeOption{inner: T.path(:f32)}
  defp rust_style_type(:px), do: %AST.TypeOption{inner: T.path(:f32)}
  defp rust_style_type(:radius), do: %AST.TypeOption{inner: T.path(:f32)}

  defp generated_apply_render_style_function(style_specs) do
    %AST.Function{
      name: :apply_generated_render_styles,
      vis: :crate,
      attrs: [A.attr(:cfg, feature: "real-gpui")],
      args: [A.arg(:element, "gpui::Div"), A.arg(:style, "StyleAttrs")],
      returns: "gpui::Div",
      body:
        [A.let_mut(:element, A.var(:element))] ++
          (style_specs
           |> Enum.reject(&is_nil(&1.render))
           |> Enum.map(&render_style_statement/1)) ++
          [A.return_stmt(A.var(:element))]
    }
    |> render_item()
  end

  defp render_style_statement(%{field: field, render: :flex_if_true}) do
    A.stmt(
      A.if_expr(
        A.field(A.var(:style), field),
        [A.assign(A.var(:element), A.method(A.var(:element), :flex))],
        []
      )
    )
  end

  defp render_style_statement(%{field: field, render: {:enum_methods, values}}) do
    arms =
      Enum.map(values, fn {value, method} ->
        %AST.Arm{
          pattern: P.some(P.lit(value)),
          body: [A.assign(A.var(:element), A.method(A.var(:element), method))]
        }
      end) ++ [%AST.Arm{pattern: P.wildcard(), body: []}]

    style_value = A.field(A.var(:style), field)
    A.stmt(A.match_expr(A.method(style_value, :as_deref), arms))
  end

  defp render_style_statement(%{field: field, render: {:enum_values, method, values}}) do
    arms =
      Enum.map(values, fn {value, path} ->
        %AST.Arm{
          pattern: P.some(P.lit(value)),
          body: [
            A.assign(A.var(:element), A.method(A.var(:element), method, [A.path(path)]))
          ]
        }
      end) ++ [%AST.Arm{pattern: P.wildcard(), body: []}]

    style_value = A.field(A.var(:style), field)
    A.stmt(A.match_expr(A.method(style_value, :as_deref), arms))
  end

  defp render_style_statement(%{field: field, render: {:option_method, method, unit}})
       when unit in [:rgb, :px, :f32] do
    rendered_value =
      case unit do
        :f32 -> A.var(:value)
        unit -> A.path_call([:gpui, unit], [A.var(:value)])
      end

    A.if_let(
      P.some(P.var(:value)),
      A.field(A.var(:style), field),
      [A.assign(A.var(:element), A.method(A.var(:element), method, [rendered_value]))]
    )
  end

  defp generated_apply_style_function(style_specs) do
    arms =
      Enum.map(style_specs, fn spec ->
        %AST.Arm{
          pattern: P.lit(to_string(spec.name)),
          body: [
            A.assign(
              A.field(A.var(:attrs), spec.field),
              style_decode_call(spec.type)
            )
          ]
        }
      end) ++ [%AST.Arm{pattern: P.wildcard(), body: []}]

    %AST.Function{
      name: :apply_generated_style_attr,
      vis: :crate,
      attrs: [
        A.attr(:cfg, feature: "real-gpui"),
        A.attr(:allow, [A.path([:clippy, :unused_unit])])
      ],
      args: [A.arg(:attrs, "&mut StyleAttrs"), A.arg(:key, "&str"), A.arg(:value, "Term")],
      returns: T.unit(),
      body: [A.stmt(A.match_expr(A.var(:key), arms))]
    }
    |> render_item()
  end

  defp style_decode_call({:atom_eq, expected}),
    do: A.call(:atom_eq, [A.var(:value), A.lit(to_string(expected))])

  defp style_decode_call(:atom_string), do: A.call(:atom_string, [A.var(:value)])
  defp style_decode_call(:rgb), do: A.call(:rgb_value, [A.var(:value)])
  defp style_decode_call(:number), do: A.call(:number_value, [A.var(:value)])
  defp style_decode_call(:px), do: A.call(:px_value, [A.var(:value)])
  defp style_decode_call(:radius), do: A.call(:radius_value, [A.var(:value)])

  defp render_item(item), do: RustQ.Rust.AST.Render.render_item(item)
end
