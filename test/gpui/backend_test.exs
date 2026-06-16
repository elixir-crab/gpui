defmodule GPUI.BackendTest do
  use ExUnit.Case, async: true

  test "fake backend aliases are unsupported" do
    assert_raise ArgumentError, ~r/unsupported GPUI backend :data/, fn ->
      GPUI.Backend.module_for(:data)
    end

    assert_raise ArgumentError, ~r/unsupported GPUI backend :remote_loopback/, fn ->
      GPUI.Backend.module_for(:remote_loopback)
    end
  end
end
