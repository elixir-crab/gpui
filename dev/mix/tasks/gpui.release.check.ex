defmodule Mix.Tasks.Gpui.Release.Check do
  use Mix.Task

  @shortdoc "Validates docs, dependencies, and the unpacked source package"

  @acknowledged_rust_advisories ["RUSTSEC-2026-0194", "RUSTSEC-2026-0195"]

  @impl Mix.Task
  def run(_args) do
    workdir = Path.join(System.tmp_dir!(), "gpui-release-#{System.unique_integer([:positive])}")
    package = Path.join(workdir, "package")
    File.mkdir_p!(workdir)

    try do
      run!("mix", ["hex.build", "--unpack", "--output", package])
      run!("mix", ["docs", "--warnings-as-errors"], fontconfig_env())
      run!("mix", ["hex.audit"])

      run!(
        "cargo",
        ["audit", "--deny", "unsound", "--file", "Cargo.lock"] ++
          Enum.flat_map(@acknowledged_rust_advisories, &["--ignore", &1])
      )

      reject_gpl3_rust_dependencies!()
      run!("mix", ["deps.get"], [{"MIX_ENV", "prod"}], package)

      run!(
        "mix",
        ["compile", "--warnings-as-errors"],
        [{"MIX_ENV", "prod"}, {"GPUI_BUILD_FROM_SOURCE", "1"} | fontconfig_env()],
        package
      )

      validate_renderer_independent_consumer!(workdir, package)
    after
      File.rm_rf!(workdir)
    end
  end

  defp validate_renderer_independent_consumer!(workdir, package) do
    consumer = Path.join(workdir, "consumer")

    write_consumer!(consumer, "mix.exs", """
    defmodule GPUIReleaseConsumer.MixProject do
      use Mix.Project

      def project do
        [
          app: :gpui_release_consumer,
          version: "0.1.0",
          elixir: "~> 1.20",
          deps: [{:gpui, path: #{inspect(package)}}]
        ]
      end

      def application, do: [extra_applications: [:logger]]
    end
    """)

    write_consumer!(consumer, "config/config.exs", """
    import Config
    config :gpui_native, build_native: config_env() != :test
    """)

    write_consumer!(consumer, "lib/release_consumer.ex", """
    defmodule GPUIReleaseConsumer.View do
      use GPUI.View

      @impl GPUI.View
      def render(assigns) do
        ~GPUI\"\"\"
        <div><text>Hello {assigns.name}</text></div>
        \"\"\"
      end
    end
    """)

    write_consumer!(consumer, "test/test_helper.exs", "ExUnit.start()\n")

    write_consumer!(consumer, "test/release_consumer_test.exs", """
    defmodule GPUIReleaseConsumerTest do
      use ExUnit.Case, async: true
      use GPUI.Test

      test "renders without compiling or loading the native NIF" do
        tree = render(GPUIReleaseConsumer.View, name: "Ada")

        assert %GPUI.Element{type: :text, children: ["Hello ", "Ada"]} =
                 find!(tree, type: :text)

        refute GPUI.Native.compiled?()
      end
    end
    """)

    env = [{"MIX_ENV", "test"}, {"GPUI_SKIP_NATIVE", "1"}]
    run!("mix", ["deps.get"], env, consumer)
    run!("mix", ["test"], env, consumer)
  end

  defp write_consumer!(root, path, contents) do
    destination = Path.join(root, path)
    File.mkdir_p!(Path.dirname(destination))
    File.write!(destination, contents)
  end

  defp reject_gpl3_rust_dependencies! do
    {output, 0} =
      System.cmd(
        "cargo",
        [
          "metadata",
          "--locked",
          "--format-version",
          "1",
          "--manifest-path",
          "Cargo.toml"
        ]
      )

    packages = JSON.decode!(output)["packages"]

    forbidden =
      Enum.filter(packages, fn package ->
        Regex.match?(~r/(?:A?GPL)-3(?:\.0)?(?:-or-later)?/, package["license"] || "")
      end)

    if forbidden != [] do
      details =
        Enum.map_join(forbidden, ", ", &"#{&1["name"]} #{&1["version"]} (#{&1["license"]})")

      Mix.raise("GPL-3 Rust dependencies are not allowed in the MIT native artifact: #{details}")
    end
  end

  defp run!(command, args, env \\ [], cd \\ File.cwd!()) do
    {_output, status} =
      System.cmd(command, args,
        cd: cd,
        env: env,
        into: IO.stream(),
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("#{command} #{Enum.join(args, " ")} failed")
  end

  defp fontconfig_env,
    do: [{"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")}]
end
