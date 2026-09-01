defmodule GPUI.Dev.Release.ChangelogTest do
  use ExUnit.Case, async: true

  alias GPUI.Dev.Release.Changelog

  test "extracts the exact version body without adjacent headings" do
    path = Path.join(System.tmp_dir!(), "gpui-changelog-#{System.unique_integer([:positive])}")

    File.write!(path, """
    # Changelog

    ## Unreleased

    ## 1.2.0-rc.1 - 2026-09-02

    ### Added

    - Public behavior.

    ## 1.1.0 - 2026-08-01

    - Previous behavior.
    """)

    on_exit(fn -> File.rm(path) end)

    assert Changelog.release_notes!(path, "1.2.0-rc.1 - 2026-09-02") ==
             "### Added\n\n- Public behavior.\n"
  end

  test "rejects missing release sections" do
    path = Path.join(System.tmp_dir!(), "gpui-changelog-#{System.unique_integer([:positive])}")
    File.write!(path, "# Changelog\n\n## Unreleased\n")
    on_exit(fn -> File.rm(path) end)

    assert_raise ArgumentError, fn -> Changelog.release_notes!(path, "1.0.0") end
  end
end
