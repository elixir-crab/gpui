defmodule Mix.Tasks.Gpui.Test.Packages do
  use Mix.Task

  @shortdoc "Builds and validates the three public packages in isolated consumers"

  @packages ~w(gpui gpui_components gpui_native)

  @impl Mix.Task
  def run(_args) do
    root = File.cwd!()
    workdir = Path.join(System.tmp_dir!(), "gpui-packages-#{System.unique_integer([:positive])}")
    packages = Path.join(workdir, "packages")

    File.mkdir_p!(packages)

    try do
      unpacked = build_packages!(root, packages)
      validate_package_contents!(unpacked)
      validate_consumer!(workdir, "gpui_consumer", [:gpui], unpacked)
      validate_consumer!(workdir, "components_consumer", [:gpui, :gpui_components], unpacked)

      validate_consumer!(
        workdir,
        "native_consumer",
        [:gpui, :gpui_components, :gpui_native],
        unpacked
      )
    after
      File.rm_rf!(workdir)
    end
  end

  defp build_packages!(root, packages) do
    Map.new(@packages, fn package ->
      destination = Path.join(packages, package)

      run!(
        "mix",
        ["hex.build", "--unpack", "--output", destination],
        package_env(),
        Path.join([root, "apps", package])
      )

      {String.to_atom(package), destination}
    end)
  end

  defp validate_package_contents!(packages) do
    assert_file!(packages.gpui, "lib/gpui.ex")
    assert_file!(packages.gpui_components, "lib/gpui/ui.ex")
    assert_file!(packages.gpui_native, "lib/gpui/native/nif.ex")
    assert_file!(packages.gpui_native, "native/gpui/Cargo.toml")
    assert_file!(packages.gpui_native, "native/gpui/Cargo.lock")

    reject_path!(packages.gpui, "codegen")
    reject_path!(packages.gpui, "dev")
    reject_path!(packages.gpui_native, "native/gpui/target")

    for package <- Map.values(packages),
        forbidden <- ["rustq.exs", "mix.lock", "deps", "_build"] do
      reject_path!(package, forbidden)
    end
  end

  defp validate_consumer!(workdir, name, apps, packages) do
    consumer = Path.join(workdir, name)
    dependencies = Enum.map(apps, &dependency_source(&1, packages))

    write!(consumer, "mix.exs", consumer_mix(name, dependencies))

    if :gpui_native in apps do
      write!(consumer, "config/config.exs", consumer_config())
    end

    write!(consumer, "test/test_helper.exs", "ExUnit.start()\n")
    write!(consumer, "test/package_test.exs", consumer_test(apps))

    run!("mix", ["deps.get"], consumer_env(), consumer)
    run!("mix", ["compile", "--warnings-as-errors"], consumer_env(), consumer)
    run!("mix", ["test"], consumer_env(), consumer)
  end

  defp dependency_source(app, packages) do
    {app, [path: Map.fetch!(packages, app), override: true]}
  end

  defp consumer_mix(name, dependencies) do
    module = name |> Macro.camelize() |> Kernel.<>(".MixProject")

    """
    defmodule #{module} do
      use Mix.Project

      def project do
        [
          app: :#{name},
          version: "0.1.0",
          elixir: "~> 1.20",
          deps: #{inspect(dependencies, pretty: true)}
        ]
      end

      def application, do: [extra_applications: [:logger]]
    end
    """
  end

  defp consumer_config do
    """
    import Config

    config :gpui_native, build_native: false
    """
  end

  defp consumer_test(apps) do
    module_assertions =
      ["assert Code.ensure_loaded?(GPUI)"] ++
        if(:gpui_components in apps, do: ["assert Code.ensure_loaded?(GPUI.UI)"], else: []) ++
        if(:gpui_native in apps,
          do: [
            "assert Code.ensure_loaded?(GPUI.Native.NIF)",
            "refute GPUI.Native.compiled?()"
          ],
          else: []
        )

    """
    defmodule PackageIsolationTest do
      use ExUnit.Case, async: true

      test "loads only the packaged public applications" do
        #{Enum.join(module_assertions, "\n    ")}
        refute Code.ensure_loaded?(RustQ)
        refute Code.ensure_loaded?(QuickBEAM)
        refute Code.ensure_loaded?(Reach)
      end
    end
    """
  end

  defp assert_file!(root, relative) do
    unless File.regular?(Path.join(root, relative)) do
      Mix.raise("package is missing #{relative}")
    end
  end

  defp reject_path!(root, relative) do
    if File.exists?(Path.join(root, relative)) do
      Mix.raise("package unexpectedly contains #{relative}")
    end
  end

  defp write!(root, relative, contents) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp package_env, do: [{"GPUI_SKIP_NATIVE", "1"}]

  defp consumer_env do
    [
      {"MIX_ENV", "test"},
      {"GPUI_SKIP_NATIVE", "1"},
      {"GPUI_BUILD_FROM_SOURCE", "0"},
      {"CARGO", Path.join(System.tmp_dir!(), "gpui-no-cargo")}
    ]
  end

  defp run!(command, args, env, cd) do
    {_output, status} =
      System.cmd(command, args,
        cd: cd,
        env: env,
        into: IO.stream(),
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("#{command} #{Enum.join(args, " ")} failed")
  end
end
