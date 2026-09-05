defmodule GPUI.Codegen.Native.ComponentHostContract.Definitions do
  @moduledoc "Defines RustQ component-host event contract types from package declarations."

  @doc "Injects component value and event types into the consuming RustQ metadata module."
  defmacro define_contract do
    variants =
      GPUI.Components.NativeContract.events()
      |> Enum.map(fn event ->
        {event.name, [quote(do: R.path(unquote(payload_type(event.payload))))]}
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
