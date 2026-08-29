defmodule Mix.Tasks.Gpui.Test.Packages do
  @moduledoc """
  Builds the public package payloads and validates them in isolated consumers.

  The consumer processes compile the exact unpacked payloads without access to
  repository-only tooling or a working Cargo executable.
  """

  use Mix.Task

  @shortdoc "Builds and validates the three public packages in isolated consumers"

  @packages [:gpui, :gpui_components, :gpui_native]

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
      package_name = Atom.to_string(package)
      destination = Path.join(packages, package_name)

      run!(
        "mix",
        ["hex.build", "--unpack", "--output", destination],
        package_env(),
        Path.join([root, "apps", package_name])
      )

      {package, destination}
    end)
  end

  defp validate_package_contents!(packages) do
    assert_file!(packages.gpui, "lib/gpui.ex")
    assert_file!(packages.gpui, "native/src/generated/schema.rs")
    assert_file!(packages.gpui_components, "lib/gpui/ui.ex")
    assert_file!(packages.gpui_components, "native/src/generated/schema.rs")
    assert_file!(packages.gpui_native, "lib/gpui/native/nif.ex")
    assert_file!(packages.gpui_native, "native/gpui/Cargo.toml")
    assert_file!(packages.gpui_native, "native/gpui/Cargo.lock")

    reject_path!(packages.gpui, "codegen")
    reject_path!(packages.gpui, "dev")
    reject_path!(packages.gpui, "native/target")
    reject_path!(packages.gpui_components, "native/target")
    reject_path!(packages.gpui_native, "native/gpui/target")

    for package <- Map.values(packages),
        forbidden <- ["rustq.exs", "mix.lock", "deps", "_build"] do
      reject_path!(package, forbidden)
    end
  end

  defp validate_consumer!(workdir, name, apps, packages) do
    consumer = Path.join(workdir, name)
    dependencies = Enum.map(apps, &dependency_source(&1, packages))

    write!(consumer, "mix.exs", consumer_mix_source(name, dependencies))

    if :gpui_native in apps do
      write!(consumer, "config/config.exs", consumer_config_source())
    end

    write!(consumer, "test/test_helper.exs", test_helper_source())
    write!(consumer, "test/package_test.exs", consumer_test_source(apps))

    run!("mix", ["deps.get"], consumer_env(), consumer)
    run!("mix", ["compile", "--warnings-as-errors"], consumer_env(), consumer)
    run!("mix", ["test"], consumer_env(), consumer)
  end

  defp dependency_source(app, packages) do
    {app, [path: Map.fetch!(packages, app), override: true]}
  end

  defp consumer_mix_source(name, dependencies) do
    module = Module.concat([Macro.camelize(name), "MixProject"])
    app = String.to_atom(name)

    quote generated: true do
      defmodule unquote(module) do
        use Mix.Project

        def project do
          [
            app: unquote(app),
            version: "0.1.0",
            elixir: "~> 1.20",
            deps: unquote(Macro.escape(dependencies))
          ]
        end

        def application, do: [extra_applications: [:logger]]
      end
    end
    |> source_from_ast()
  end

  defp consumer_config_source do
    quote generated: true do
      import Config

      config :gpui_native, build_native: false
    end
    |> source_from_ast()
  end

  defp test_helper_source do
    quote generated: true do
      ExUnit.start()
    end
    |> source_from_ast()
  end

  defp consumer_test_source(apps) do
    assertions =
      [
        quote(do: assert(Code.ensure_loaded?(GPUI))),
        quote(do: refute(Code.ensure_loaded?(RustQ))),
        quote(do: refute(Code.ensure_loaded?(QuickBEAM))),
        quote(do: refute(Code.ensure_loaded?(Reach)))
      ]
      |> maybe_add_assertion(
        apps == [:gpui],
        quote(do: refute(Code.ensure_loaded?(GPUI.Components.Schema)))
      )
      |> maybe_add_assertion(
        apps == [:gpui],
        quote do
          assert GPUI.Schema.Registry.native_tags(GPUI.Schema.registry()) ==
                   Enum.map(GPUI.Schema.Core.components(), & &1.tag)
        end
      )
      |> maybe_add_assertion(
        :gpui_components in apps,
        quote(do: assert(Code.ensure_loaded?(GPUI.UI)))
      )
      |> maybe_add_assertion(
        :gpui_components in apps,
        quote do
          registry =
            GPUI.Schema.registry()
            |> GPUI.Schema.Registry.include(GPUI.Schema.Surfaces)
            |> GPUI.Schema.Registry.include(GPUI.Components.Schema.Declarations)

          assert :ui_button in GPUI.Schema.Registry.native_tags(registry)
        end
      )
      |> maybe_add_assertion(
        :gpui_native in apps,
        quote(do: assert(Code.ensure_loaded?(GPUI.Native.NIF)))
      )
      |> maybe_add_assertion(
        :gpui_native in apps,
        quote(do: refute(GPUI.Native.compiled?()))
      )

    quote generated: true do
      defmodule PackageIsolationTest do
        @moduledoc false

        use ExUnit.Case, async: true

        test "loads only the packaged public applications" do
          (unquote_splicing(assertions))
        end
      end
    end
    |> source_from_ast()
  end

  defp source_from_ast(ast) do
    ast
    |> Macro.to_string()
    |> Code.format_string!()
    |> then(&[&1, ?\n])
    |> IO.iodata_to_binary()
  end

  defp maybe_add_assertion(assertions, true, assertion), do: assertions ++ [assertion]
  defp maybe_add_assertion(assertions, false, _assertion), do: assertions

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
