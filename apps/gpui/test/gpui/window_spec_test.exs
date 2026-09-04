defmodule GPUI.WindowSpecTest do
  use ExUnit.Case, async: true

  defmodule View do
    use GPUI.View

    @impl GPUI.View
    def render(_assigns), do: %GPUI.Element{type: :div}
  end

  test "builds and validates a dynamic window from keyword options" do
    assert %GPUI.WindowSpec{
             key: "details",
             title: "Details",
             size: {420, 240},
             root: {View, %{label: "Detail"}}
           } =
             GPUI.WindowSpec.new("Details",
               key: "details",
               size: {420, 240},
               root: {View, label: "Detail"}
             )
  end

  test "accepts a root module with empty assigns" do
    assert %GPUI.WindowSpec{root: {View, %{}}} = GPUI.WindowSpec.new("Details", root: View)
  end

  test "rejects invalid options through the ordinary validation contract" do
    assert_raise ArgumentError, ~r/window size/, fn ->
      GPUI.WindowSpec.new("Details", size: {0, 240}, root: View)
    end
  end
end
