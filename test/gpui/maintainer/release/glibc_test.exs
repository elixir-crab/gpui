defmodule GPUI.Maintainer.Release.GlibcTest do
  use ExUnit.Case, async: true

  test "parses and compares multi-digit GLIBC versions as integer tuples" do
    output = "GLIBC_2.9 GLIBC_2.35 GLIBC_2.36 GLIBC_3.0 GLIBC_2.9"

    assert GPUI.Maintainer.Release.Glibc.required_versions(output) == [
             {2, 9},
             {2, 35},
             {2, 36},
             {3, 0}
           ]

    assert GPUI.Maintainer.Release.Glibc.parse_version!("2.35") == {2, 35}
    assert_raise ArgumentError, fn -> GPUI.Maintainer.Release.Glibc.parse_version!("2") end
  end

  test "accepts an archive at the ceiling and rejects a newer requirement" do
    archive = archive!("libdemo.so")
    on_exit(fn -> File.rm_rf!(Path.dirname(archive)) end)

    script =
      executable!("""
      #!/bin/sh
      echo '000 GLIBC_2.9'
      echo '000 GLIBC_2.35'
      """)

    assert :ok =
             GPUI.Maintainer.Release.Glibc.check_archive!(archive, max: {2, 35}, objdump: script)

    File.write!(script, "#!/bin/sh\necho '000 GLIBC_2.36'\n")

    assert_raise Mix.Error, ~r/requires GLIBC_2.36, exceeding supported GLIBC_2.35/, fn ->
      GPUI.Maintainer.Release.Glibc.check_archive!(archive, max: "2.35", objdump: script)
    end
  end

  test "rejects malformed native archive inventories" do
    archive = archive!("README.txt")
    on_exit(fn -> File.rm_rf!(Path.dirname(archive)) end)

    assert_raise Mix.Error, ~r/contains no dynamic library/, fn ->
      GPUI.Maintainer.Release.Glibc.check_archive!(archive, max: "2.35", objdump: "/usr/bin/true")
    end
  end

  defp archive!(name) do
    directory = temp_dir!("archive")
    input = Path.join(directory, name)
    File.write!(input, "native")
    archive = Path.join(directory, "native.tar.gz")
    :ok = :erl_tar.create(String.to_charlist(archive), [String.to_charlist(input)], [:compressed])
    archive
  end

  defp executable!(contents) do
    directory = temp_dir!("objdump")
    path = Path.join(directory, "objdump")
    File.write!(path, contents)
    File.chmod!(path, 0o755)
    on_exit(fn -> File.rm_rf!(directory) end)
    path
  end

  defp temp_dir!(name) do
    path =
      Path.join(
        System.tmp_dir!(),
        "gpui-glibc-test-#{name}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    path
  end
end
