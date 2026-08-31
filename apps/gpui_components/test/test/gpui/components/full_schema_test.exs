defmodule GPUI.Components.FullSchemaTest do
  use ExUnit.Case, async: true

  alias GPUI.Schema.Registry

  test "composes the complete component host from provider-owned declarations" do
    registry =
      GPUI.Schema.registry()
      |> Registry.include(GPUI.Schema.Surfaces)
      |> Registry.include(GPUI.Components.Schema.Declarations)

    assert Registry.native_tags(registry) ==
             GPUI.Schema.Core.components()
             |> Kernel.++(GPUI.Schema.Surfaces.components())
             |> Kernel.++(GPUI.Components.Schema.Declarations.components())
             |> Enum.map(& &1.tag)

    assert Registry.provider!(registry, :ui_button) == GPUI.Components.Schema.Declarations
    assert Registry.provider!(registry, :ui_paint) == GPUI.Schema.Surfaces
    assert Registry.component!(registry, :ui_input).required_events == [:"phx-change"]
    assert Registry.component!(registry, :ui_sidebar_item).kind == :sidebar_item_component
    assert Registry.component!(registry, :ui_status_bar).children
    assert Registry.component!(registry, :ui_separator).children == false
    assert Registry.component!(registry, :text_surface).required_events == []
  end

  test "derives public option documentation from component contracts" do
    slider_doc = GPUI.Components.Schema.component_options_doc(:ui_slider)
    assert slider_doc =~ "## Options"
    assert slider_doc =~ "| `:label` | non-empty `String.t()` | yes | — |"
    assert slider_doc =~ "| `:\"phx-change\"` | non-empty event name | yes | — |"

    tooltip_doc = GPUI.Components.Schema.component_options_doc(:ui_tooltip)
    assert tooltip_doc =~ "| `:trigger` | one named slot | yes | — |"
    assert tooltip_doc =~ "| `:content` | one named slot | yes | — |"
    refute tooltip_doc =~ "`:text`"
  end

  test "projects component defaults for builders and native decoders" do
    assert %{file_max_bytes: 10_485_760, disabled: false} =
             GPUI.Components.Schema.defaults(:ui_button)

    assert %{item_height: 40.0, total_count: 0, disabled: false} =
             GPUI.Components.Schema.defaults(:ui_tree)

    assert %{max: 250.0, value: 10.0} =
             GPUI.Components.Schema.apply_defaults(
               %{max: 250.0, value: 10.0},
               :ui_progress
             )
  end
end
