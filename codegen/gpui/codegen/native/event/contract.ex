defmodule GPUI.Codegen.Native.Event.Contract do
  @moduledoc "Owns native event variants and their wire encoder dispatch together."

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias RustQ.Spec

  defp declarations do
    named = [window_id: quote(do: RustQ.Type.u64()), event: quote(do: String.t())]
    window = [window_id: quote(do: RustQ.Type.u64())]
    value = quote(do: RustQ.Type.option(EventValue.t()))

    [
      {:Copy, "components", named, :encode_named_event, [:env, atom(:copy), :window_id, :event]},
      {:Click, nil, named, :encode_named_event, [:env, atom(:click), :window_id, :event]},
      {:Command, nil, named, :encode_named_event, [:env, atom(:command), :window_id, :event]},
      {:Input, nil, [kind: quote(do: InputKind.t())] ++ named ++ [value: value],
       :encode_input_event, [:env, A.ref(:kind), :window_id, :event, :value]}
    ] ++
      revisioned(named) ++
      [
        {:Focus, "real-gpui",
         [kind: quote(do: InputKind.t())] ++ named ++ [id: quote(do: String.t())],
         :encode_focus_event, [:env, A.ref(:kind), :window_id, :event, :id]},
        {:Bounds, "real-gpui", named ++ [value: quote(do: ElementBoundsGeometry.t())],
         :encode_bounds_event, [:env, :window_id, :event, :value]},
        {:ClipboardWrite, "components", named, :encode_named_event,
         [:env, atom(:clipboard_write), :window_id, :event]},
        {:ClipboardRead, "components", named ++ [payload: quote(do: TransferPayload.t())],
         :encode_clipboard_event, [:env, :window_id, :event, :payload]},
        {:Transfer, "components",
         [kind: quote(do: InputKind.t())] ++ named ++ [value: quote(do: TransferEventValue.t())],
         :encode_transfer_event, [:env, A.ref(:kind), :window_id, :event, :value]},
        {:WindowCloseRequest, nil, window, :encode_window_event,
         [:env, atom(:window_close_request), :window_id]},
        {:WindowFocus, nil, [focused: quote(do: boolean())] ++ window, :encode_window_event,
         [
           :env,
           %AST.If{
             condition: A.var(:focused),
             then: [A.return_stmt(atom(:window_focus))],
             else: [A.return_stmt(atom(:window_blur))]
           },
           :window_id
         ]},
        {:WindowClosed, nil, window, :encode_window_event,
         [:env, atom(:window_closed), :window_id]},
        {:VirtualRange, "components",
         named ++ [first: quote(do: RustQ.Type.u64()), last: quote(do: RustQ.Type.u64())],
         :encode_virtual_range_event, [:env, :window_id, :event, :first, :last]},
        {:FileDialog, "components",
         named ++
           [operation_id: quote(do: RustQ.Type.u64()), result: quote(do: FileDialogResult.t())],
         :encode_file_dialog_event,
         [
           :env,
           :window_id,
           :event,
           %AST.Try{expr: A.call(:encode_file_dialog_result, [:env, :operation_id, :result])}
         ]},
        {:MissingResource, "real-gpui", window ++ [id: quote(do: String.t())],
         :encode_missing_resource_event, [:env, :window_id, :id]}
      ]
  end

  defp revisioned(named) do
    [
      {:Transaction, :transaction, quote(do: TextTransaction.t()),
       :encode_revisioned_transaction_event, :transaction},
      {:Selection, :selections, quote(do: RustQ.Type.vec(Crate.TextSelection.t())),
       :encode_revisioned_selection_event, :selection},
      {:Viewport, :value, quote(do: TextViewportGeometry.t()), :encode_revisioned_viewport_event,
       :viewport},
      {:Geometry, :value, quote(do: TextCaretGeometry.t()), :encode_revisioned_geometry_event,
       :geometry},
      {:RangeGeometry, :value, quote(do: RustQ.Type.vec(TextRangeGeometry.t())),
       :encode_revisioned_range_geometry_event, :range_geometry},
      {:HitTest, :value, quote(do: Crate.TextPosition.t()), :encode_revisioned_position_event,
       :hit_test}
    ]
    |> Enum.map(fn {variant, field, type, encoder, kind} ->
      {variant, "components", named ++ [{field, type}, {:revision, quote(do: RustQ.Type.u64())}],
       encoder, [:env, atom(kind), :window_id, :event, field, :revision]}
    end)
  end

  defp atom(name), do: A.path_call([:atoms, name], [])
  defp attrs(nil), do: []
  defp attrs(feature), do: [A.attr(:cfg, feature: feature)]

  @spec items() :: [AST.item()]
  def items do
    declarations = declarations()

    variants =
      Enum.map(declarations, fn {name, feature, fields, _encoder, _args} ->
        %AST.EnumVariant{
          name: name,
          attrs: attrs(feature),
          fields:
            Enum.map(fields, fn {name, type} ->
              %AST.StructField{name: name, type: Spec.type(type).ast}
            end)
        }
      end)

    arms =
      Enum.map(declarations, fn {name, feature, fields, encoder, args} ->
        %AST.Arm{
          attrs: attrs(feature),
          pattern:
            P.struct(
              [:NativeEvent, name],
              Enum.map(fields, fn {name, _} -> {name, P.var(name)} end)
            ),
          body: [A.return_stmt(A.call(encoder, args))]
        }
      end)

    [
      %AST.Enum{name: :NativeEvent, vis: :crate, derive: [:Clone, :Debug], variants: variants},
      %AST.Function{
        name: :encode_native_event,
        vis: :crate,
        lifetimes: [:a],
        args:
          A.function_args(
            env: Spec.type(quote(do: Env.t(RustQ.Type.lifetime(:a)))).ast,
            event: A.type_path(:NativeEvent)
          ),
        returns: Spec.type(quote(do: RustQ.Type.nif_result(Term.t(RustQ.Type.lifetime(:a))))).ast,
        body: [A.return_stmt(A.match_expr(A.var(:event), arms))]
      }
    ]
  end
end
