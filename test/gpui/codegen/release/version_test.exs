defmodule GPUI.Dev.Release.VersionTest do
  use ExUnit.Case, async: false

  alias GPUI.Dev.Release.Version, as: ReleaseVersion

  test "reads coordinated semantic versions from package projects" do
    versions = Enum.map(~w(gpui gpui_components gpui_native), &ReleaseVersion.fetch!/1)

    assert [%Version{} = version, second, third] = versions
    assert second == version
    assert third == version
    assert ReleaseVersion.prerelease?(version)
  end

  test "rejects unknown packages" do
    assert_raise ArgumentError, "unknown package: unknown", fn ->
      ReleaseVersion.fetch!("unknown")
    end
  end
end
