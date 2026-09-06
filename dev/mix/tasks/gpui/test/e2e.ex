defmodule Mix.Tasks.Gpui.Test.E2e do
  @moduledoc "Builds local desktop infrastructure and runs native E2E tests."
  use Mix.Task

  @shortdoc "Runs local GPUI desktop E2E tests"
  @project_root GPUI.Maintainer.Paths.app(:gpui_native)
  @macos_driver Path.join(@project_root, "test/support/desktop/drivers/macos")

  @linux_groups [
    {"rich text and transcript", ~w(
       apps/gpui_native/test/e2e/gpui/native/rich_text_test.exs
       apps/gpui_native/test/e2e/gpui/native/rich_transcript_test.exs
       apps/gpui_native/test/e2e/gpui/native/composer_transcript_test.exs
       apps/gpui_native/test/e2e/gpui/native/virtual_collection_test.exs
     )},
    {"editable text", ~w(
       apps/gpui_native/test/e2e/gpui/native/text_surface_test.exs
       apps/gpui_native/test/e2e/gpui/native/text_style_run_test.exs
     )},
    {"overlays and topology", ~w(
       apps/gpui_native/test/e2e/gpui/native/overlay_test.exs
       apps/gpui_native/test/e2e/gpui/native/multi_window_topology_test.exs
     )},
    {"remote display", ~w(apps/gpui_native/test/e2e/gpui/remote)},
    {"native controls and examples", ~w(
       apps/gpui_native/test/e2e/gpui/native/code_viewer_test.exs
       apps/gpui_native/test/e2e/gpui/native/components_test.exs
       apps/gpui_native/test/e2e/gpui/native/data_table_test.exs
       apps/gpui_native/test/e2e/gpui/native/display_controls_test.exs
       apps/gpui_native/test/e2e/gpui/native/form_controls_test.exs
       apps/gpui_native/test/e2e/gpui/native/image_lab_test.exs
       apps/gpui_native/test/e2e/gpui/native/interactivity_test.exs
       apps/gpui_native/test/e2e/gpui/native/lifecycle_test.exs
       apps/gpui_native/test/e2e/gpui/native/split_test.exs
       apps/gpui_native/test/e2e/gpui/native/tree_test.exs
       apps/gpui_native/test/e2e/gpui/native/virtual_list_test.exs
     )}
  ]

  @impl Mix.Task
  def run(args) do
    case :os.type() do
      {:unix, :darwin} -> prepare_macos!()
      {:unix, _name} -> prepare_linux!()
      platform -> Mix.raise("local desktop E2E is unsupported on #{inspect(platform)}")
    end

    run_tests!(args)
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

  defp run_tests!([]) do
    case :os.type() do
      {:unix, :darwin} -> run!("mix", test_command(["apps/gpui_native/test/e2e"]), macos_env())
      {:unix, _name} -> run_linux_groups!()
    end
  end

  defp run_tests!(test_args) do
    command = test_command(test_args)

    case :os.type() do
      {:unix, :darwin} -> run!("mix", command, macos_env())
      {:unix, _name} -> run_linux_tests!(command)
    end
  end

  defp run_linux_groups! do
    failures =
      Enum.count(@linux_groups, fn {name, paths} ->
        Mix.shell().info("Native E2E: #{name}")
        run_linux_tests(test_command(paths)) != 0
      end)

    if failures > 0, do: Mix.raise("#{failures} native E2E groups failed")
  end

  defp run_linux_tests!(command) do
    if run_linux_tests(command) != 0, do: Mix.raise("native E2E tests failed")
  end

  defp run_linux_tests(command) do
    args = ["-a", "dbus-run-session", "--", "mix" | command]
    run("xvfb-run", args, linux_env())
  end

  defp test_command(paths), do: ["test", "--only", "e2e" | paths]
  defp macos_env, do: [{"MIX_ENV", "e2e"}]

  defp linux_env do
    [
      {"MIX_ENV", "e2e"},
      {"RUST_FONTCONFIG_DLOPEN", "1"},
      {"LIBGL_ALWAYS_SOFTWARE", "1"},
      {"GALLIUM_DRIVER", "llvmpipe"}
    ]
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
    if run(executable, args, env) != 0,
      do: Mix.raise("#{executable} #{Enum.join(args, " ")} failed")
  end

  defp run(executable, args, env) do
    {_output, status} =
      System.cmd(executable, args,
        into: IO.stream(),
        stderr_to_stdout: true,
        env: env
      )

    status
  end
end
