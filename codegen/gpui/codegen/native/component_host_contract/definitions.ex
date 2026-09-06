defmodule GPUI.Codegen.Native.ComponentHostContract.Definitions do
  @moduledoc "Defines RustQ component-host event contract types from package declarations."

  @doc "Injects component value and event types into the consuming RustQ metadata module."
  # This schema computes native type names as atoms. Keep R.path at this
  # metaprogramming boundary; concrete specs use ordinary remote types.
  defmacro define_contract do
    variants =
      GPUI.Components.NativeContract.events()
      |> Enum.map(fn event ->
        {event.name, [quote(do: R.path(unquote(payload_type(event.payload))))]}
      end)

    envelope_clauses =
      Enum.map(GPUI.Components.NativeContract.events(), fn event ->
        pattern = quote(do: enum_variant(Self, unquote(event.name), value))

        body =
          if event.payload == :none, do: quote(do: value), else: quote(do: ref(value.envelope))

        {:->, [], [[pattern], body]}
      end)

    quote do
      @type component_value ::
              R.enum(
                boolean: [boolean()],
                string: [String.t()],
                strings: [R.vec(String.t())],
                number: [R.f64()],
                none: []
              )

      @type component_event :: R.enum(unquote(variants))

      defrustimpl ComponentEvent, vis: :pub do
        @spec envelope(R.ref(component_event())) :: R.ref(ComponentEventEnvelope.t())
        defrust envelope(self) do
          case self do
            (unquote_splicing(envelope_clauses))
          end
        end
      end
    end
  end

  defp payload_type(:none), do: :ComponentEventEnvelope
  defp payload_type(:value), do: :ComponentValueEvent
  defp payload_type(:input), do: :ComponentInputEvent
  defp payload_type(:transfer), do: :ComponentTransferEvent
  defp payload_type(:file_dialog), do: :ComponentFileDialogEvent
  defp payload_type(:text_geometry), do: :ComponentTextGeometryEvent
  defp payload_type(:text_position), do: :ComponentTextPositionEvent
  defp payload_type(:text_range_geometry), do: :ComponentTextRangeGeometryEvent
  defp payload_type(:text_selection), do: :ComponentTextSelectionEvent
  defp payload_type(:text_transaction), do: :ComponentTextTransactionEvent
  defp payload_type(:text_viewport), do: :ComponentTextViewportEvent
end
