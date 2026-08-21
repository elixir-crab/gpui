defmodule GPUI.Native do
  @moduledoc "Low-level Rustler NIF facade generated and selected at compile time."

  build_native? =
    System.get_env("GPUI_BUILD_FROM_SOURCE") in ["1", "true"] or
      Application.compile_env(:gpui, :build_native, false)

  skip_native? = System.get_env("GPUI_SKIP_NATIVE") in ["1", "true"]
  @compiled build_native? and not skip_native?

  @doc "Reports whether this build loaded the native NIF implementation."
  @spec compiled?() :: boolean()
  def compiled?, do: :persistent_term.get({__MODULE__, :compiled}, @compiled)

  if @compiled do
    version = Mix.Project.config()[:version]
    project_root = __DIR__ |> Path.dirname() |> Path.dirname()
    checksum = Path.join(project_root, "checksum-Elixir.GPUI.Native.exs")
    system_architecture = :erlang.system_info(:system_architecture) |> List.to_string()

    precompiled_target? =
      String.starts_with?(system_architecture, "x86_64") and
        String.contains?(system_architecture, "linux") and
        not String.contains?(system_architecture, "musl")

    force_build? =
      System.get_env("GPUI_BUILD_FROM_SOURCE") in ["1", "true"] or
        not precompiled_target? or not File.exists?(checksum)

    source_variant =
      cond do
        Mix.env() == :e2e -> "desktop"
        Mix.env() == :test and Mix.target() == :native_test -> "native_test"
        true -> "core"
      end

    # Rustler always copies a source build to `gpui_nif`, so copy that result
    # once to a target-specific load path before this module's on-load hook runs.
    # Subsequent Mix targets can then compile and load independently without
    # replacing the library already selected by another build directory.
    source_artifact = "gpui_nif_#{source_variant}"

    rustler_opts = [
      otp_app: :gpui,
      crate: "gpui_nif",
      path: "native/gpui",
      base_url: "https://github.com/dannote/gpui/releases/download/v#{version}",
      version: version,
      targets: ["x86_64-unknown-linux-gnu"],
      nif_versions: ["2.15"],
      force_build: force_build?
    ]

    rustler_opts =
      if force_build? do
        Keyword.put(rustler_opts, :load_from, {:gpui, "priv/native/#{source_artifact}"})
      else
        rustler_opts
      end

    use RustlerPrecompiled, rustler_opts

    if force_build? do
      extension = if match?({:win32, _}, :os.type()), do: ".dll", else: ".so"
      source = Path.join(project_root, "priv/native/gpui_nif#{extension}")
      destination = Path.join(project_root, "priv/native/#{source_artifact}#{extension}")
      File.cp!(source, destination)
    end
  end

  use GPUI.Native.Generated
end
