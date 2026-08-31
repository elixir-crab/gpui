defmodule GPUI.Application.IdentityTest do
  use ExUnit.Case, async: true

  test "validates bounded application metadata" do
    icon =
      GPUI.Application.Icon.new!(source: "priv/branding/example", description: "Example icon")

    assert %GPUI.Application.Identity{id: "com.example.desktop", name: "Example", icon: ^icon} =
             GPUI.Application.Identity.new!(
               id: "com.example.desktop",
               name: "Example",
               icon: icon
             )

    assert_raise ArgumentError, ~r/reverse-DNS/, fn ->
      GPUI.Application.Identity.new!(id: "example", name: "Example")
    end

    assert_raise ArgumentError, ~r/name/, fn ->
      GPUI.Application.Identity.new!(id: "com.example.desktop", name: "")
    end
  end

  test "rejects unsafe icon sources" do
    assert_raise ArgumentError, ~r/without traversal/, fn ->
      GPUI.Application.Icon.new!(source: "../icon.png")
    end

    assert_raise ArgumentError, ~r/relative path/, fn ->
      GPUI.Application.Icon.new!(source: "/tmp/icon.png")
    end
  end
end
