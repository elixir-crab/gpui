defmodule GPUI.Dev.NativeWorkspaceTest do
  use ExUnit.Case, async: true

  alias GPUI.Dev.NativeWorkspace

  test "loads decoded metadata from the repository workspace" do
    metadata = NativeWorkspace.metadata!(["--no-default-features", "--features", "vanilla-host"])

    assert Enum.any?(metadata.packages, &(&1.name == "gpui_nif"))
  end
end
