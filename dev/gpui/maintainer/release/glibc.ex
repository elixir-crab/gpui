defmodule GPUI.Maintainer.Release.Glibc do
  @moduledoc false

  @type version :: {non_neg_integer(), non_neg_integer()}

  @spec parse_version!(String.t()) :: version()
  def parse_version!(version) when is_binary(version) do
    case String.split(version, ".") do
      [major, minor] -> {parse_component!(major, version), parse_component!(minor, version)}
      _other -> raise ArgumentError, "invalid GLIBC version: #{inspect(version)}"
    end
  end

  @spec required_versions(String.t()) :: [version()]
  def required_versions(output) when is_binary(output) do
    ~r/GLIBC_(\d+)\.(\d+)/
    |> Regex.scan(output, capture: :all_but_first)
    |> Enum.map(fn [major, minor] -> {String.to_integer(major), String.to_integer(minor)} end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec check_archive!(Path.t(), keyword()) :: :ok
  def check_archive!(archive, opts) do
    maximum = Keyword.fetch!(opts, :max)
    maximum = if is_binary(maximum), do: parse_version!(maximum), else: maximum
    executable = Keyword.get(opts, :objdump, System.find_executable("objdump"))

    unless valid_version?(maximum), do: raise(ArgumentError, "invalid maximum GLIBC version")
    unless executable, do: Mix.raise("objdump is required to inspect GLIBC symbol versions")
    unless File.regular?(archive), do: Mix.raise("native archive does not exist: #{archive}")

    with_temp_dir(fn directory ->
      extract_archive!(archive, directory)
      library = single_library!(directory)
      output = command!(executable, ["-T", library])
      versions = required_versions(output)

      case Enum.filter(versions, &version_newer?(&1, maximum)) do
        [] -> :ok
        newer ->
          required = newer |> Enum.max() |> format_version()
          supported = format_version(maximum)
          Mix.raise("native archive requires #{required}, exceeding supported #{supported}")
      end
    end)
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

  defp single_library!(directory) do
    libraries =
      directory
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&(File.regular?(&1) and Path.extname(&1) in [".so", ".dylib", ".dll"]))

    case libraries do
      [library] -> library
      [] -> Mix.raise("native archive contains no dynamic library")
      _many -> Mix.raise("native archive must contain exactly one dynamic library")
    end
  end

  defp command!(executable, args) do
    case System.cmd(executable, args, stderr_to_stdout: true) do
      {output, 0} -> output
      {output, status} -> Mix.raise("#{Path.basename(executable)} failed with #{status}:\n#{output}")
    end
  end

  defp with_temp_dir(callback) do
    directory = Path.join(System.tmp_dir!(), "gpui-glibc-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)

    try do
      callback.(directory)
    after
      File.rm_rf!(directory)
    end
  end

  defp parse_component!(component, source) do
    case Integer.parse(component) do
      {value, ""} -> value
      _other -> raise ArgumentError, "invalid GLIBC version: #{inspect(source)}"
    end
  end

  defp valid_version?({major, minor}), do: is_integer(major) and major >= 0 and is_integer(minor) and minor >= 0
  defp valid_version?(_version), do: false
  defp version_newer?({major, minor}, {max_major, max_minor}), do: major > max_major or (major == max_major and minor > max_minor)
  defp format_version({major, minor}), do: "GLIBC_#{major}.#{minor}"
end
