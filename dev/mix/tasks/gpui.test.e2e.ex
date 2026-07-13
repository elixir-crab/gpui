defmodule Mix.Tasks.Gpui.Test.E2e do
  use Mix.Task

  @shortdoc "Runs native GPUI interaction tests under an isolated X server"

  @impl Mix.Task
  def run(_args) do
    ensure_dependencies!()

    env = [
      {"GPUI_E2E", "1"},
      {"MIX_ENV", "test"},
      {"MIX_BUILD_PATH", Path.expand("_build/e2e")},
      {"RUST_FONTCONFIG_DLOPEN", System.get_env("RUST_FONTCONFIG_DLOPEN", "1")},
      {"VK_ICD_FILENAMES",
       System.get_env("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/lvp_icd.json")}
    ]

    args = [
      "-a",
      "-s",
      "-screen 0 1280x720x24",
      "dbus-run-session",
      "--",
      "mix",
      "test",
      "--only",
      "e2e",
      "test/e2e"
    ]

    {_output, status} =
      System.cmd("xvfb-run", args, env: env, into: IO.stream(), stderr_to_stdout: true)

    if status != 0, do: Mix.raise("native E2E suite failed")
  end

  defp ensure_dependencies! do
    for executable <- ~w(cargo dbus-run-session xdotool xvfb-run),
        System.find_executable(executable) == nil do
      Mix.raise("native E2E dependency not found: #{executable}")
    end
  end
end
