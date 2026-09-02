defmodule Mix.Tasks.Gpui.Release.Check do
  use Mix.Task

  @shortdoc "Validates public packages, docs, and dependency licenses"

  @acknowledged_rust_advisories ["RUSTSEC-2026-0194", "RUSTSEC-2026-0195"]
  @packages ~w(gpui gpui_components gpui_native)

  @impl Mix.Task
  def run(_args) do
    root = File.cwd!()

    docs_env = dev_env() ++ fontconfig_env()
    run!("mix", ["deps.get"], docs_env, root)
    run!("mix", ["deps.compile", "ex_doc"], docs_env, root)

    gpui_dir = Path.join([root, "apps", "gpui"])
    run!("mix", ["docs", "--warnings-as-errors"], docs_env, gpui_dir)

    Enum.each(@packages, fn package ->
      package_dir = Path.join([root, "apps", package])
      run!("mix", ["hex.audit"], dev_env(), package_dir)
    end)

    Mix.Task.run("gpui.test.packages")

    GPUI.Dev.NativeWorkspace.audit!(
      Enum.flat_map(@acknowledged_rust_advisories, &["--ignore", &1])
    )

    reject_gpl3_rust_dependencies!()
  end

  defp reject_gpl3_rust_dependencies! do
    packages = GPUI.Dev.NativeWorkspace.metadata!().packages

    forbidden =
      Enum.filter(packages, fn package ->
        Regex.match?(~r/(?:A?GPL)-3(?:\.0)?(?:-or-later)?/, package.license || "")
      end)

    if forbidden != [] do
      details =
        Enum.map_join(forbidden, ", ", &"#{&1.name} #{&1.version} (#{&1.license})")

      Mix.raise("GPL-3 Rust dependencies are not allowed in the MIT native artifact: #{details}")
    end
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

  defp fontconfig_env,
    do: [{"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")}]

  defp dev_env, do: [{"MIX_ENV", "dev"}, {"GPUI_SKIP_NATIVE", "1"}]
end
