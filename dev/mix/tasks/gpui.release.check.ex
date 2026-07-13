defmodule Mix.Tasks.Gpui.Release.Check do
  use Mix.Task

  @shortdoc "Validates docs, dependencies, and the unpacked source package"

  @impl Mix.Task
  def run(_args) do
    workdir = Path.join(System.tmp_dir!(), "gpui-release-#{System.unique_integer([:positive])}")
    package = Path.join(workdir, "package")
    File.mkdir_p!(workdir)

    try do
      run!("mix", ["hex.build", "--unpack", "--output", package])
      run!("mix", ["docs", "--warnings-as-errors"], fontconfig_env())
      run!("mix", ["hex.audit"])
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
