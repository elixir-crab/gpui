defmodule GPUI.GeneratedNativeDocsTest do
  use ExUnit.Case, async: true

  test "generated native boundary functions retain source documentation" do
    assert_fully_documented(GPUI.Native.Backend)
    assert_fully_documented(GPUI.Native.Test)
  end

  defp assert_fully_documented(module) do
    {:docs_v1, _annotation, _language, _format, _module_doc, _metadata, entries} =
      Code.fetch_docs(module)

    undocumented =
      for {{kind, name, arity}, _annotation, _signatures, documentation, _metadata} <- entries,
          kind in [:function, :macro],
          documentation in [:none, :hidden],
          do: {name, arity}

    assert undocumented == [], "expected every #{inspect(module)} function to be documented"
  end
end
