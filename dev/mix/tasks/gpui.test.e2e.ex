defmodule Mix.Tasks.Gpui.Test.E2e do
  @moduledoc "Builds local desktop infrastructure and runs native E2E tests."
  use Mix.Task

  @shortdoc "Runs local GPUI desktop E2E tests"
  @project_root Path.expand("../../../apps/gpui_native", __DIR__)
  @macos_driver Path.join(@project_root, "test/support/desktop/drivers/macos")

  @impl Mix.Task
  def run(args) do
    case :os.type() do
      {:unix, :darwin} -> prepare_macos!()
      {:unix, _name} -> prepare_linux!()
      platform -> Mix.raise("local desktop E2E is unsupported on #{inspect(platform)}")
    end

    test_args = if args == [], do: ["test/e2e"], else: args
    run_tests!(test_args)
  end

  defp prepare_macos! do
    ensure_executable!("swift")

    ensure_macos_permission!(
      "Accessibility",
      "import ApplicationServices; print(AXIsProcessTrusted())"
    )

    ensure_macos_permission!(
      "Screen Recording",
      "import CoreGraphics; print(CGPreflightScreenCaptureAccess())"
    )

    run!("swift", ["build", "--package-path", @macos_driver, "-c", "release"])
  end

  defp prepare_linux! do
    Enum.each(["xvfb-run", "dbus-run-session", "xdotool"], &ensure_executable!/1)
  end

  defp run_tests!(test_args) do
    command = ["test", "--only", "e2e" | test_args]

    case :os.type() do
      {:unix, :darwin} -> run!("mix", command, [{"MIX_ENV", "e2e"}])
      {:unix, _name} -> run_linux_tests!(command)
    end
  end

  defp run_linux_tests!(command) do
    args = ["-a", "dbus-run-session", "--", "mix" | command]

    env = [
      {"MIX_ENV", "e2e"},
      {"RUST_FONTCONFIG_DLOPEN", "1"},
      {"LIBGL_ALWAYS_SOFTWARE", "1"},
      {"GALLIUM_DRIVER", "llvmpipe"}
    ]

    run!("xvfb-run", args, env)
  end

  defp ensure_macos_permission!(name, expression) do
    case System.cmd("swift", ["-e", expression], stderr_to_stdout: true) do
      {"true\n", 0} -> :ok
      {output, _status} -> Mix.raise("#{name} permission is required for local E2E: #{output}")
    end
  end

  defp ensure_executable!(name) do
    if System.find_executable(name),
      do: :ok,
      else: Mix.raise("#{name} is required for local desktop E2E")
  end

  defp run!(executable, args, env \\ []) do
    {_output, status} =
      System.cmd(executable, args,
        into: IO.stream(),
        stderr_to_stdout: true,
        env: env
      )

    if status != 0, do: Mix.raise("#{executable} #{Enum.join(args, " ")} failed")
  end
end
