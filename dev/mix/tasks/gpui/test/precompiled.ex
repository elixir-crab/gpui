defmodule Mix.Tasks.Gpui.Test.Precompiled do
  @moduledoc """
  Validates a published precompiled host in a clean, no-Cargo consumer.

  Run this after `checksum-Elixir.GPUI.Native.NIF.exs` has been generated from
  the archives attached to the coordinated GitHub release.
  """

  use Mix.Task

  @shortdoc "Loads one published native host without a Rust toolchain"
  @switches [host: :string]
  @packages [:gpui, :gpui_components, :gpui_native]

  @impl Mix.Task
  def run(args) do
    {options, remaining} = OptionParser.parse!(args, strict: @switches)
    if remaining != [], do: Mix.raise("unexpected arguments: #{Enum.join(remaining, " ")}")

    host = parse_host!(Keyword.fetch!(options, :host))
    root = File.cwd!()
    checksum = Path.join(root, "apps/gpui_native/checksum-Elixir.GPUI.Native.NIF.exs")

    unless File.regular?(checksum) do
      Mix.raise("missing RustlerPrecompiled checksum manifest: #{checksum}")
    end

    workdir =
      Path.join(
        System.tmp_dir!(),
        "gpui-precompiled-#{host}-#{System.unique_integer([:positive])}"
      )

    try do
      packages = build_packages!(root, Path.join(workdir, "packages"))
      validate_consumer!(Path.join(workdir, "consumer"), host, packages)
    after
      cleanup(workdir)
    end
  end

  defp cleanup(path) do
    case File.rm_rf(path) do
      {:ok, _files} -> :ok
      {:error, _reason, _file} -> :ok
    end
  end

  defp parse_host!("vanilla"), do: :vanilla
  defp parse_host!("gpui_component"), do: :gpui_component
  defp parse_host!(host), do: Mix.raise("unsupported precompiled host: #{inspect(host)}")

  defp build_packages!(root, packages_root) do
    File.mkdir_p!(packages_root)

    Map.new(@packages, fn package ->
      name = Atom.to_string(package)
      destination = Path.join(packages_root, name)

      run!(
        "mix",
        ["hex.build", "--unpack", "--output", destination],
        package_env(),
        Path.join([root, "apps", name])
      )

      {package, destination}
    end)
  end

  defp validate_consumer!(consumer, host, packages) do
    dependencies =
      Enum.map(@packages, fn package ->
        {package, [path: Map.fetch!(packages, package), override: true]}
      end)

    write_ast!(consumer, "mix.exs", consumer_mix_ast(dependencies))
    write_ast!(consumer, "config/config.exs", consumer_config_ast(host))
    write_ast!(consumer, "test/test_helper.exs", quote(do: ExUnit.start()))
    write_ast!(consumer, "test/precompiled_test.exs", consumer_test_ast(host))

    run!("mix", ["deps.get"], consumer_env(host), consumer)
    run!("mix", ["compile", "--warnings-as-errors"], consumer_env(host), consumer)
    run!("mix", ["test"], consumer_env(host), consumer)
  end

  defp consumer_mix_ast(dependencies) do
    quote generated: true do
      defmodule GPUIPrecompiledConsumer.MixProject do
        use Mix.Project

        def project do
          [
            app: :gpui_precompiled_consumer,
            version: "0.1.0",
            elixir: "~> 1.20",
            deps: unquote(Macro.escape(dependencies))
          ]
        end

        def application, do: [extra_applications: [:logger]]
      end
    end
  end

  defp consumer_config_ast(host) do
    quote generated: true do
      import Config

      config :gpui_native, build_native: true
      config :gpui_native, GPUI.Native, host: unquote(host)
    end
  end

  defp consumer_test_ast(host) do
    quote generated: true do
      defmodule GPUIPrecompiledConsumerTest do
        use ExUnit.Case, async: false

        test "loads the selected precompiled host" do
          assert GPUI.Native.available?()
          assert GPUI.Native.Backend.host_info() == {:ok, unquote(host)}
        end
      end
    end
  end

  defp write_ast!(root, relative, ast) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))

    source =
      ast
      |> Macro.to_string()
      |> Code.format_string!()
      |> then(&[&1, ?\n])
      |> IO.iodata_to_binary()

    File.write!(path, source)
  end

  defp package_env, do: [{"GPUI_SKIP_NATIVE", "1"}]

  defp consumer_env(host) do
    [
      {"MIX_ENV", "test"},
      {"GPUI_NATIVE_HOST", Atom.to_string(host)},
      {"GPUI_BUILD_FROM_SOURCE", "0"},
      {"GPUI_SKIP_NATIVE", "0"},
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
