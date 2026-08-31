GPUITest.Examples.load!(:component_gallery)

defmodule GPUI.ComponentGalleryCatalogTest do
  use ExUnit.Case, async: true

  alias Examples.ComponentGallery.Catalog

  test "catalog has deterministic unique story identities and complete contracts" do
    entries = Catalog.entries()

    assert length(entries) == 19
    assert Enum.uniq_by(entries, & &1.id) == entries

    assert Enum.all?(entries, fn entry ->
             function_exported?(entry.module, :metadata, 0) and
               function_exported?(entry.module, :initial_state, 0) and
               function_exported?(entry.module, :render_story, 1)
           end)
  end
end
