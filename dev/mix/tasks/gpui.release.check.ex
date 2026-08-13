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
        ["audit", "--deny", "unsound", "--file", "native/gpui/Cargo.lock"] ++
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
    after
      File.rm_rf!(workdir)
    end
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
          "native/gpui/Cargo.toml"
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
