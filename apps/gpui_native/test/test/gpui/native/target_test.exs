defmodule GPUI.Native.TargetTest do
  use ExUnit.Case, async: true

  test "recognizes supported runtime architecture names independently of Cargo vendors" do
    assert GPUI.Native.Target.precompiled?("x86_64-pc-linux-gnu")
    assert GPUI.Native.Target.precompiled?("x86_64-unknown-linux-gnu")
    assert GPUI.Native.Target.precompiled?("aarch64-apple-darwin")
    assert GPUI.Native.Target.precompiled?("x86_64-pc-windows")
    assert GPUI.Native.Target.precompiled?("x86_64-pc-windows-msvc")
  end

  test "rejects architectures without published precompiled hosts" do
    refute GPUI.Native.Target.precompiled?("aarch64-unknown-linux-gnu")
    refute GPUI.Native.Target.precompiled?("x86_64-unknown-linux-musl")
    refute GPUI.Native.Target.precompiled?("x86_64-apple-darwin")
    refute GPUI.Native.Target.precompiled?("aarch64-pc-windows")
  end
end
