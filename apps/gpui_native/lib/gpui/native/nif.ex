defmodule GPUI.Native.NIF do
  @moduledoc "Low-level Rustler NIF facade generated and selected at compile time."

  build_native? =
    System.get_env("GPUI_BUILD_FROM_SOURCE") in ["1", "true"] or
      Application.compile_env(:gpui_native, :build_native, true)

  skip_native? = System.get_env("GPUI_SKIP_NATIVE") in ["1", "true"]
  @compiled build_native? and not skip_native?

  @doc "Reports whether this build loaded the native NIF implementation."
  @spec compiled?() :: boolean()
  def compiled?, do: :persistent_term.get({__MODULE__, :compiled}, @compiled)

  if @compiled do
    version = Mix.Project.config()[:version]
    project_root = Mix.Project.project_file() |> Path.dirname() |> Path.expand()
    checksum = Path.join(project_root, "checksum-Elixir.GPUI.Native.NIF.exs")
    system_architecture = :erlang.system_info(:system_architecture) |> List.to_string()

    precompiled_target? = GPUI.Native.Target.precompiled?(system_architecture)

    source_checkout? =
      project_root
      |> Stream.unfold(fn path ->
        parent = Path.dirname(path)
        {path, if(parent == path, do: nil, else: parent)}
      end)
      |> Enum.any?(&File.dir?(Path.join(&1, ".git")))

    release_metadata? = Mix.env() == :release and source_checkout?

    force_build? =
      (source_checkout? and not release_metadata?) or
        System.get_env("GPUI_BUILD_FROM_SOURCE") in ["1", "true"] or
        not precompiled_target? or not File.exists?(checksum)

    host =
      case System.get_env("GPUI_NATIVE_HOST") do
        "vanilla" -> :vanilla
        "gpui_component" -> :gpui_component
        nil -> Application.compile_env(:gpui_native, [GPUI.Native, :host], :vanilla)
        value -> raise ArgumentError, "unsupported GPUI_NATIVE_HOST: #{inspect(value)}"
      end

    source_variant =
      cond do
        System.get_env("MIX_TARGET") == "native_test" -> "native_test"
        System.get_env("MIX_ENV") == "e2e" -> "desktop"
        host == :vanilla -> "vanilla"
        host == :gpui_component -> "gpui-component"
        true -> raise ArgumentError, "unsupported GPUI native host: #{inspect(host)}"
      end

    features =
      cond do
        System.get_env("MIX_TARGET") == "native_test" -> ["native-test"]
        System.get_env("MIX_ENV") == "e2e" -> ["gpui-component-host"]
        System.get_env("ZED_HEADLESS") == "1" -> ["real-gpui"]
        host == :gpui_component -> ["gpui-component-host"]
        host == :vanilla -> ["vanilla-host"]
      end

    # Rustler always copies a source build to `gpui_nif`, so copy that result
    # once to a target-specific load path before this module's on-load hook runs.
    # Subsequent Mix targets can then compile and load independently without
    # replacing the library already selected by another build directory.
    source_artifact = "gpui_nif_#{source_variant}"

    rustler_opts = [
      otp_app: :gpui_native,
      crate: "gpui_nif",
      path: "native",
      base_url: "https://github.com/elixir-crab/gpui/releases/download/v#{version}",
      version: version,
      targets: [
        "aarch64-apple-darwin",
        "x86_64-pc-windows-msvc",
        "x86_64-unknown-linux-gnu"
      ],
      nif_versions: ["2.15"],
      variants: %{
        "aarch64-apple-darwin" => [
          vanilla: fn -> host == :vanilla end,
          "gpui-component": fn -> host == :gpui_component end
        ],
        "x86_64-pc-windows-msvc" => [
          vanilla: fn -> host == :vanilla end,
          "gpui-component": fn -> host == :gpui_component end
        ],
        "x86_64-unknown-linux-gnu" => [
          vanilla: fn -> host == :vanilla end,
          "gpui-component": fn -> host == :gpui_component end
        ]
      },
      force_build: force_build?,
      default_features: false,
      features: features
    ]

    rustler_opts =
      if force_build? do
        Keyword.put(rustler_opts, :load_from, {:gpui_native, "priv/native/#{source_artifact}"})
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
