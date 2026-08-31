defmodule GPUI.Application.IdentityTest do
  use ExUnit.Case, async: true

  test "validates bounded application metadata" do
    assert %GPUI.Application.Identity{id: "com.example.desktop", name: "Example"} =
             GPUI.Application.Identity.new!(id: "com.example.desktop", name: "Example")

    assert_raise ArgumentError, ~r/reverse-DNS/, fn ->
      GPUI.Application.Identity.new!(id: "example", name: "Example")
    end

    assert_raise ArgumentError, ~r/name/, fn ->
      GPUI.Application.Identity.new!(id: "com.example.desktop", name: "")
    end
  end
end
