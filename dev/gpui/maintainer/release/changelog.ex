defmodule GPUI.Maintainer.Release.Changelog do
  @moduledoc "Extracts canonical release notes from Markdown changelogs."

  @spec release_notes!(Path.t(), String.t()) :: String.t()
  def release_notes!(path, version) do
    heading_prefix = "## #{version}"

    path
    |> File.stream!(:line, [])
    |> Enum.reduce_while(:before, fn line, state ->
      trimmed = String.trim_trailing(line)

      case state do
        :before ->
          if trimmed == heading_prefix or String.starts_with?(trimmed, heading_prefix <> " - ") do
            {:cont, {:inside, []}}
          else
            {:cont, :before}
          end

        {:inside, lines} ->
          if String.starts_with?(trimmed, "## ") do
            {:halt, {:inside, lines}}
          else
            {:cont, {:inside, [line | lines]}}
          end
      end
    end)
    |> notes!(version, path)
  end

  defp notes!({:inside, lines}, version, path) do
    notes = lines |> Enum.reverse() |> IO.iodata_to_binary() |> String.trim()

    if notes == "" do
      raise ArgumentError, "empty changelog section for #{version} in #{path}"
    end

    notes <> "\n"
  end

  defp notes!(:before, version, path) do
    raise ArgumentError, "missing changelog section for #{version} in #{path}"
  end
end
