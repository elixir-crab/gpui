defmodule GPUI.Dev.Release.Inventory do
  @moduledoc "Writes structured native and Mix dependency inventories."

  @spec write!(Path.t()) :: :ok
  def write!(directory) do
    File.mkdir_p!(directory)

    cargo =
      GPUI.Dev.NativeWorkspace
      |> apply(:output!, [["metadata", "--format-version", "1"]])

    File.write!(Path.join(directory, "cargo-metadata.json"), cargo)

    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    try do
      Mix.Task.reenable("deps.tree")
      Mix.Task.run("deps.tree", ["--format", "plain"])
      File.write!(Path.join(directory, "mix-dependencies.txt"), collect_output([]))
    after
      Mix.shell(shell)
    end
  end

  defp collect_output(lines) do
    receive do
      {:mix_shell, :info, [line]} -> collect_output([line | lines])
      {:mix_shell, :error, [line]} -> collect_output([line | lines])
    after
      0 -> lines |> Enum.reverse() |> Enum.intersperse("\n") |> IO.iodata_to_binary()
    end
  end
end
