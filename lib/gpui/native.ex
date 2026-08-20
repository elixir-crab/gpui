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
    checksum = Path.expand("../../checksum-Elixir.GPUI.Native.exs", __DIR__)
    system_architecture = :erlang.system_info(:system_architecture) |> List.to_string()

    precompiled_target? =
      String.starts_with?(system_architecture, "x86_64") and
        String.contains?(system_architecture, "linux") and
        not String.contains?(system_architecture, "musl")

    force_build? =
      System.get_env("GPUI_BUILD_FROM_SOURCE") in ["1", "true"] or
        not precompiled_target? or not File.exists?(checksum)

    use RustlerPrecompiled,
      otp_app: :gpui,
      crate: "gpui_nif",
      path: "native/gpui",
      base_url: "https://github.com/dannote/gpui/releases/download/v#{version}",
      version: version,
      targets: ["x86_64-unknown-linux-gnu"],
      nif_versions: ["2.15"],
      force_build: force_build?
  end

  use GPUI.Native.Generated
end
