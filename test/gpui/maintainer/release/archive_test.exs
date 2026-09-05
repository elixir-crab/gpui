defmodule GPUI.Maintainer.Release.ArchiveTest do
  use ExUnit.Case, async: true

  alias GPUI.Maintainer.Release.Archive

  test "derives exact RustlerPrecompiled names for each platform" do
    assert Archive.archive_name("0.2.0-rc.2", "x86_64-unknown-linux-gnu", :vanilla) ==
             "libgpui_nif-v0.2.0-rc.2-nif-2.15-x86_64-unknown-linux-gnu--vanilla.so.tar.gz"

    assert Archive.archive_name("0.2.0-rc.2", "aarch64-apple-darwin", :gpui_component) ==
             "libgpui_nif-v0.2.0-rc.2-nif-2.15-aarch64-apple-darwin--gpui-component.so.tar.gz"

    assert Archive.archive_name("0.2.0-rc.2", "x86_64-pc-windows-msvc", :vanilla) ==
             "gpui_nif-v0.2.0-rc.2-nif-2.15-x86_64-pc-windows-msvc--vanilla.dll.tar.gz"
  end

  test "validates Linux archive architecture and GLIBC ceiling" do
    archive = archive!("0.2.0-rc.2", "x86_64-unknown-linux-gnu", :vanilla, "native")
    on_exit(fn -> File.rm_rf!(Path.dirname(archive)) end)

    objdump = executable!("objdump", "#!/bin/sh\necho '000 GLIBC_2.35'\n")
    file = executable!("file", "#!/bin/sh\necho 'ELF 64-bit LSB shared object, x86-64'\n")

    assert :ok =
             Archive.check!(archive,
               version: "0.2.0-rc.2",
               target: "x86_64-unknown-linux-gnu",
               host: :vanilla,
               tools: %{objdump: objdump, file: file}
             )
  end

  test "validates macOS system linkage" do
    archive = archive!("0.2.0-rc.2", "aarch64-apple-darwin", :gpui_component, "native")
    on_exit(fn -> File.rm_rf!(Path.dirname(archive)) end)

    file =
      executable!(
        "file",
        "#!/bin/sh\necho 'Mach-O 64-bit dynamically linked shared library arm64'\n"
      )

    otool =
      executable!("otool", """
      #!/bin/sh
      echo "$2:"
      echo '  /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0)'
      echo '  /usr/lib/libSystem.B.dylib (compatibility version 1.0.0)'
      """)

    assert :ok =
             Archive.check!(archive,
               version: "0.2.0-rc.2",
               target: "aarch64-apple-darwin",
               host: :gpui_component,
               tools: %{file: file, otool: otool}
             )
  end

  test "validates Windows PE architecture and system dependencies" do
    archive = archive!("0.2.0-rc.2", "x86_64-pc-windows-msvc", :vanilla, "native")
    on_exit(fn -> File.rm_rf!(Path.dirname(archive)) end)

    dumpbin =
      executable!("dumpbin", """
      #!/bin/sh
      case "$1" in
        /headers) echo '8664 machine (x64)' ;;
        /dependents) printf 'kernel32.dll\\nVCRUNTIME140.dll\\napi-ms-win-crt-runtime-l1-1-0.dll\\n' ;;
      esac
      """)

    assert :ok =
             Archive.check!(archive,
               version: "0.2.0-rc.2",
               target: "x86_64-pc-windows-msvc",
               host: :vanilla,
               tools: %{dumpbin: dumpbin}
             )
  end

  defp archive!(version, target, host, contents) do
    directory = temp_dir!("archive")
    name = Archive.archive_name(version, target, host)
    extension = name |> String.trim_trailing(".tar.gz") |> Path.extname()
    library = Path.join(directory, "gpui_nif#{extension}")
    File.write!(library, contents)
    archive = Path.join(directory, name)

    File.cd!(directory, fn ->
      :ok =
        :erl_tar.create(
          String.to_charlist(archive),
          [String.to_charlist(Path.basename(library))],
          [:compressed]
        )
    end)

    archive
  end

  defp executable!(name, contents) do
    directory = temp_dir!(name)
    path = Path.join(directory, name)
    File.write!(path, contents)
    File.chmod!(path, 0o755)
    on_exit(fn -> File.rm_rf!(directory) end)
    path
  end

  defp temp_dir!(name) do
    path =
      Path.join(
        System.tmp_dir!(),
        "gpui-archive-test-#{name}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(path)
    path
  end
end
