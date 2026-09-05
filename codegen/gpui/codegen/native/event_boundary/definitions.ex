defmodule GPUI.Codegen.Native.EventBoundary.Definitions do
  @moduledoc "Defines the closed injectable event-kind type used by the native boundary."

  @doc "Injects the closed native event-kind type into a RustQ metadata module."
  defmacro define_inject_kind do
    type = GPUI.Event.injectable_types() |> Enum.reverse() |> Enum.reduce(&{:|, [], [&1, &2]})

    quote do
      @type inject_kind :: unquote(type)
    end
  end
end
