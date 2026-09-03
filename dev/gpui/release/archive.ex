defmodule GPUI.Dev.Release.Archive do
  @moduledoc "Validates one RustlerPrecompiled host archive and its native library."

  @glibc_maximum {2, 35}
  @windows_system_libraries ~w(
    advapi32.dll bcryptprimitives.dll combase.dll comctl32.dll d3d11.dll dcomp.dll
    dwrite.dll dwmapi.dll dxgi.dll gdi32.dll gdiplus.dll icuuc.dll imm32.dll
    kernel32.dll ntdll.dll ole32.dll oleaut32.dll shell32.dll uiautomationcore.dll
    user32.dll userenv.dll vcruntime140.dll winmm.dll
  )

  @type host :: :vanilla | :gpui_component

  @spec check!(Path.t(), keyword()) :: :ok
  def check!(archive, options) do
    version = options |> Keyword.fetch!(:version) |> Version.parse!() |> to_string()
    target = Keyword.fetch!(options, :target)
    host = Keyword.fetch!(options, :host)
    tools = Keyword.get(options, :tools, %{})

    unless File.regular?(archive), do: Mix.raise("native archive does not exist: #{archive}")

    expected = archive_name(version, target, host)

    if Path.basename(archive) != expected do
      Mix.raise("native archive name must be #{expected}, got #{Path.basename(archive)}")
    end

    with_temp_dir(fn directory ->
      extract_archive!(archive, directory)
      library = single_library!(directory, target)
      check_platform!(archive, library, target, tools)
    end)
  end

  @spec archive_name(String.t(), String.t(), host()) :: String.t()
  def archive_name(version, target, host) do
    {prefix, extension} = library_name_parts(target)
    variant = if host == :gpui_component, do: "gpui-component", else: "vanilla"
    "#{prefix}gpui_nif-v#{version}-nif-2.15-#{target}--#{variant}.#{extension}.tar.gz"
  end

  defp check_platform!(archive, library, "x86_64-unknown-linux-gnu", tools) do
    GPUI.Dev.Release.Glibc.check_archive!(archive,
      max: @glibc_maximum,
      objdump: Map.get(tools, :objdump, System.find_executable("objdump"))
    )

    output = command!(tool!(tools, :file, "file"), [library])

    unless output =~ "ELF 64-bit" and output =~ "x86-64",
      do: Mix.raise("library is not x86-64 ELF")

    :ok
  end

  defp check_platform!(_archive, library, "aarch64-apple-darwin", tools) do
    output = command!(tool!(tools, :file, "file"), [library])

    unless output =~ "Mach-O 64-bit" and output =~ "arm64",
      do: Mix.raise("library is not arm64 Mach-O")

    linkage = command!(tool!(tools, :otool, "otool"), ["-L", library])
    reject_non_system_macos_libraries!(linkage)
  end

  defp check_platform!(_archive, library, "x86_64-pc-windows-msvc", tools) do
    dumpbin = Map.get(tools, :dumpbin) || find_dumpbin!()
    headers = command!(dumpbin, ["/headers", library])

    unless Regex.match?(~r/8664 machine \(x64\)/i, headers),
      do: Mix.raise("library is not x86-64 PE")

    dependencies = command!(dumpbin, ["/dependents", library]) |> windows_dependencies()

    case dependencies -- @windows_system_libraries do
      [] ->
        :ok

      unexpected ->
        Mix.raise("Windows DLL has unexpected dependencies: #{Enum.join(unexpected, ", ")}")
    end
  end

  defp check_platform!(_archive, _library, target, _tools),
    do: Mix.raise("unsupported native archive target: #{target}")

  defp reject_non_system_macos_libraries!(output) do
    unexpected =
      output
      |> String.split("\n", trim: true)
      |> Enum.drop(1)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&(String.split(&1, " (", parts: 2) |> hd()))
      |> Enum.reject(
        &(String.starts_with?(&1, "/System/Library/") or String.starts_with?(&1, "/usr/lib/"))
      )
      |> Enum.reject(&String.ends_with?(&1, "/libgpui_nif.dylib"))

    if unexpected == [],
      do: :ok,
      else: Mix.raise("macOS library has unexpected dependencies: #{Enum.join(unexpected, ", ")}")
  end

  defp windows_dependencies(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&Regex.match?(~r/^(?:api-ms-|ext-ms-).+\.dll$|^[a-z0-9_.-]+\.dll$/i, &1))
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(String.starts_with?(&1, "api-ms-") or String.starts_with?(&1, "ext-ms-")))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp find_dumpbin! do
    program_files =
      System.get_env("ProgramFiles(x86)") || Mix.raise("ProgramFiles(x86) is unavailable")

    vswhere = Path.join([program_files, "Microsoft Visual Studio", "Installer", "vswhere.exe"])

    installation =
      command!(vswhere, [
        "-latest",
        "-products",
        "*",
        "-requires",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "-property",
        "installationPath"
      ])
      |> String.trim()

    installation
    |> Path.join("VC/Tools/MSVC/*/bin/Hostx64/x64/dumpbin.exe")
    |> Path.wildcard()
    |> Enum.sort(:desc)
    |> List.first()
    |> case do
      nil -> Mix.raise("dumpbin was not found")
      path -> path
    end
  end

  defp library_name_parts(target) do
    cond do
      String.ends_with?(target, "-pc-windows-msvc") -> {"", "dll"}
      String.ends_with?(target, "-apple-darwin") -> {"lib", "so"}
      target == "x86_64-unknown-linux-gnu" -> {"lib", "so"}
      true -> Mix.raise("unsupported native archive target: #{target}")
    end
  end

  defp single_library!(directory, target) do
    {_prefix, extension} = library_name_parts(target)

    libraries =
      directory
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(
        &(File.regular?(&1) and String.downcase(Path.extname(&1)) == ".#{extension}")
      )

    case libraries do
      [library] -> library
      [] -> Mix.raise("native archive contains no .#{extension} library")
      _many -> Mix.raise("native archive must contain exactly one dynamic library")
    end
  end

  defp extract_archive!(archive, directory) do
    case :erl_tar.extract(String.to_charlist(Path.expand(archive)), [
           :compressed,
           {:cwd, String.to_charlist(directory)}
         ]) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("failed to extract native archive: #{inspect(reason)}")
    end
  end

  defp tool!(tools, key, executable),
    do:
      Map.get(tools, key) || System.find_executable(executable) ||
        Mix.raise("#{executable} is required")

  defp command!(executable, arguments) do
    case System.cmd(executable, arguments, stderr_to_stdout: true) do
      {output, 0} ->
        output

      {output, status} ->
        Mix.raise("#{Path.basename(executable)} failed with #{status}:\n#{output}")
    end
  end

  defp with_temp_dir(callback) do
    directory = Path.join(System.tmp_dir!(), "gpui-archive-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)

    try do
      callback.(directory)
    after
      File.rm_rf!(directory)
    end
  end
end
