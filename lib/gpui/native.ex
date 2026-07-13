defmodule GPUI.Native do
  @moduledoc false

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

  use GPUI.Native.Generated
end
