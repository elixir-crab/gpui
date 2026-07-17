defmodule Examples.GitRepositoryBrowser.Command do
  @moduledoc false

  @timeout 30_000

  def run(executable, args, max_bytes) do
    case System.find_executable(executable) do
      nil ->
        {:error, :executable_not_found}

      path ->
        port =
          Port.open(
            {:spawn_executable, path},
            [:binary, :exit_status, :stderr_to_stdout, args: args]
          )

        collect(port, max_bytes, 0, [])
    end
  end

  defp collect(port, max_bytes, size, chunks) do
    receive do
      {^port, {:data, data}} when size + byte_size(data) <= max_bytes ->
        collect(port, max_bytes, size + byte_size(data), [data | chunks])

      {^port, {:data, _data}} ->
        Port.close(port)
        {:error, :output_too_large}

      {^port, {:exit_status, 0}} ->
        {:ok, chunks |> Enum.reverse() |> IO.iodata_to_binary()}

      {^port, {:exit_status, status}} ->
        {:error, {:exit_status, status, chunks |> Enum.reverse() |> IO.iodata_to_binary()}}
    after
      @timeout ->
        Port.close(port)
        {:error, :timeout}
    end
  end
end

defmodule Examples.GitRepositoryBrowser.Repository do
  @moduledoc false

  alias Examples.GitRepositoryBrowser.Command

  @scan_limit 20 * 1_024 * 1_024
  @preview_limit 1 * 1_024 * 1_024
  @line_limit 20_000

  def scan(path, opts \\ []) when is_binary(path) do
    git = Keyword.get(opts, :git, &git/3)
    path = Path.expand(path)

    with {:ok, root_output} <- git.(path, ["rev-parse", "--show-toplevel"], 4_096),
         root when root != "" <- String.trim(root_output),
         {:ok, branch_output} <- git.(root, ["branch", "--show-current"], 4_096),
         {:ok, files_output} <-
           git.(
             root,
             ["ls-files", "-z", "--cached", "--others", "--exclude-standard"],
             @scan_limit
           ),
         {:ok, status_output} <-
           git.(root, ["status", "--porcelain=v1", "-z", "--untracked-files=all"], @scan_limit) do
      statuses = parse_status(status_output)

      files =
        files_output
        |> split_zero()
        |> Enum.filter(&String.valid?/1)
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.map(fn relative_path ->
          %{
            path: relative_path,
            name: Path.basename(relative_path),
            status: Map.get(statuses, relative_path, :clean)
          }
        end)

      {:ok,
       %{
         root: root,
         name: Path.basename(root),
         branch: branch_name(branch_output),
         files: files,
         counts: status_counts(files)
       }}
    else
      {:error, reason} -> {:error, format_error(path, reason)}
      "" -> {:error, "#{path} is not inside a Git repository"}
    end
  end

  def preview(repository, relative_path, opts \\ [])
      when is_map(repository) and is_binary(relative_path) do
    git = Keyword.get(opts, :git, &git/3)
    read = Keyword.get(opts, :read, &read_bounded/2)

    with :ok <- validate_relative_path(relative_path),
         {:ok, content, mode} <- preview_content(repository, relative_path, git, read) do
      {:ok,
       %{
         path: relative_path,
         mode: mode,
         status: file_status(repository.files, relative_path),
         lines: lines(content, mode)
       }}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, format_error(relative_path, reason)}
    end
  end

  defp preview_content(repository, relative_path, git, read) do
    status = file_status(repository.files, relative_path)

    if status == :untracked do
      read_file(repository.root, relative_path, read)
    else
      case git.(
             repository.root,
             [
               "diff",
               "--no-ext-diff",
               "--no-textconv",
               "--unified=3",
               "HEAD",
               "--",
               relative_path
             ],
             @preview_limit
           ) do
        {:ok, diff} when diff != "" ->
          {:ok, diff, :diff}

        {:ok, ""} ->
          read_file(repository.root, relative_path, read)

        {:error, :output_too_large} ->
          {:ok, "Diff exceeds the #{@preview_limit} byte preview limit.", :notice}

        {:error, _reason} when status == :added ->
          read_file(repository.root, relative_path, read)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp read_file(root, relative_path, read) do
    path = Path.join(root, relative_path)

    case read.(path, @preview_limit) do
      {:ok, data} ->
        cond do
          byte_size(data) > @preview_limit ->
            {:ok, "File exceeds the #{@preview_limit} byte preview limit.", :notice}

          :binary.match(data, <<0>>) != :nomatch ->
            {:ok, "Binary file preview is unavailable.", :notice}

          String.valid?(data) ->
            {:ok, data, :file}

          true ->
            {:ok, "File is not valid UTF-8.", :notice}
        end

      {:error, :enoent} ->
        {:ok, "File does not exist in the working tree.", :notice}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_bounded(path, max_bytes) do
    with {:ok, %File.Stat{type: :regular}} <- File.lstat(path),
         {:ok, file} <- File.open(path, [:read, :binary]) do
      try do
        case IO.binread(file, max_bytes + 1) do
          data when is_binary(data) -> {:ok, data}
          :eof -> {:ok, ""}
          {:error, reason} -> {:error, reason}
        end
      after
        File.close(file)
      end
    else
      {:ok, %File.Stat{type: type}} -> {:error, "cannot preview #{type} repository entries"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_relative_path(path) do
    parts = Path.split(path)

    if Path.type(path) == :relative and parts != [] and
         Enum.all?(parts, &(&1 not in ["", ".", ".."])) do
      :ok
    else
      {:error, "invalid repository-relative path"}
    end
  end

  defp lines(content, mode) do
    content
    |> String.split("\n")
    |> Enum.take(@line_limit + 1)
    |> Enum.with_index(1)
    |> Enum.map(fn
      {_line, index} when index > @line_limit ->
        %{
          id: "line-truncated",
          number: nil,
          text: "Preview truncated after #{@line_limit} lines.",
          kind: :notice
        }

      {line, index} ->
        %{id: "line-#{index}", number: index, text: line_text(line), kind: line_kind(line, mode)}
    end)
  end

  defp line_text(""), do: " "
  defp line_text(line), do: line

  defp line_kind(_line, :notice), do: :notice
  defp line_kind("+++" <> _rest, :diff), do: :header
  defp line_kind("---" <> _rest, :diff), do: :header
  defp line_kind("@@" <> _rest, :diff), do: :hunk
  defp line_kind("+" <> _rest, :diff), do: :added
  defp line_kind("-" <> _rest, :diff), do: :deleted
  defp line_kind("diff " <> _rest, :diff), do: :header
  defp line_kind(_line, _mode), do: :context

  defp parse_status(output), do: output |> split_zero() |> parse_status_records(%{})

  defp parse_status_records([], statuses), do: statuses

  defp parse_status_records([record | records], statuses) when byte_size(record) >= 4 do
    code = binary_part(record, 0, 2)
    path = binary_part(record, 3, byte_size(record) - 3)
    status = classify_status(code)
    statuses = Map.put(statuses, path, status)

    if String.contains?(code, ["R", "C"]) do
      parse_status_records(Enum.drop(records, 1), statuses)
    else
      parse_status_records(records, statuses)
    end
  end

  defp parse_status_records([_record | records], statuses),
    do: parse_status_records(records, statuses)

  defp classify_status("??"), do: :untracked

  defp classify_status(code) do
    cond do
      String.contains?(code, "D") -> :deleted
      String.contains?(code, "R") -> :renamed
      String.contains?(code, "C") -> :added
      String.contains?(code, "A") -> :added
      true -> :modified
    end
  end

  defp split_zero(output), do: String.split(output, <<0>>, trim: true)

  defp status_counts(files) do
    Enum.reduce(files, %{changed: 0, clean: 0, total: length(files)}, fn file, counts ->
      key = if file.status == :clean, do: :clean, else: :changed
      Map.update!(counts, key, &(&1 + 1))
    end)
  end

  defp file_status(files, relative_path) do
    case Enum.find(files, &(&1.path == relative_path)) do
      nil -> :clean
      file -> file.status
    end
  end

  defp branch_name(output) do
    case String.trim(output) do
      "" -> "detached HEAD"
      branch -> branch
    end
  end

  defp git(root, args, max_bytes),
    do: Command.run("git", ["-C", root | args], max_bytes)

  defp format_error(subject, {:exit_status, _status, output}) do
    message = output |> String.trim() |> String.split("\n") |> List.first()
    "#{subject}: #{message}"
  end

  defp format_error(subject, :output_too_large),
    do: "#{subject}: command output exceeded its bound"

  defp format_error(subject, :timeout), do: "#{subject}: Git command timed out"

  defp format_error(subject, :executable_not_found),
    do: "#{subject}: git executable was not found"

  defp format_error(subject, reason) when is_atom(reason),
    do: "#{subject}: #{:file.format_error(reason)}"

  defp format_error(subject, reason), do: "#{subject}: #{inspect(reason)}"
end
