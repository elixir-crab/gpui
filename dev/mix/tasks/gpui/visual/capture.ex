defmodule Mix.Tasks.Gpui.Visual.Capture do
  use Mix.Task

  @shortdoc "Captures synchronized native visual scenarios"
  @project_root GPUI.Maintainer.Paths.app(:gpui_native)
  @scenario_dir Path.join(@project_root, "test/visual/scenarios")

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          inner: :boolean,
          output: :string,
          theme: :string,
          scenario: :string,
          all: :boolean
        ]
      )

    if invalid != [], do: Mix.raise("invalid visual capture options: #{inspect(invalid)}")

    output = opts |> Keyword.get(:output, "tmp/gpui-visual") |> Path.expand()
    theme = opts |> Keyword.get(:theme, "dark") |> parse_theme!()
    requested = if opts[:all], do: :all, else: Keyword.get(opts, :scenario, "component_gallery")

    if opts[:inner] do
      capture_requested(requested, output, theme)
    else
      run_isolated(requested, output, theme)
    end
  end

  defp run_isolated(requested, output, theme) do
    ensure_executables!()

    target_args =
      case requested do
        :all -> ["--all"]
        scenario -> ["--scenario", scenario]
      end

    args =
      [
        "-a",
        "-s",
        "-screen 0 1280x1000x24",
        "dbus-run-session",
        "--",
        "mix",
        "gpui.visual.capture",
        "--inner",
        "--output",
        output,
        "--theme",
        Atom.to_string(theme)
      ] ++ target_args

    {_output, status} =
      System.cmd("xvfb-run", args, into: IO.stream(), stderr_to_stdout: true)

    if status != 0, do: Mix.raise("visual capture failed")
  end

  defp capture_requested(requested, output, theme) do
    scenarios = load_scenarios!()

    selected =
      case requested do
        :all ->
          scenarios |> Map.values() |> Enum.sort_by(& &1.id())

        id ->
          case Map.fetch(scenarios, id) do
            {:ok, scenario} -> [scenario]
            :error -> Mix.raise(unknown_scenario_message(id, scenarios))
          end
      end

    File.mkdir_p!(output)

    for scenario <- selected do
      scenario_output =
        if requested == :all, do: Path.join(output, to_string(scenario.id())), else: output

      capture_scenario!(scenario, scenario_output, theme)
    end
  end

  defp load_scenarios! do
    @scenario_dir
    |> Path.join("*.exs")
    |> Path.wildcard()
    |> Enum.each(fn path ->
      path |> Path.basename(".exs") |> GPUI.Maintainer.Visual.ScenarioLoader.load!()
    end)

    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(&visual_scenario?/1)
    |> Enum.reduce(%{}, fn scenario, scenarios ->
      id = scenario.id() |> Atom.to_string()

      if Map.has_key?(scenarios, id) do
        Mix.raise("duplicate visual scenario #{inspect(id)}")
      end

      Map.put(scenarios, id, scenario)
    end)
  end

  defp visual_scenario?(module) do
    function_exported?(module, :module_info, 1) and
      GPUI.Maintainer.Visual.Scenario in Keyword.get(module.module_info(:attributes), :behaviour, [])
  end

  defp unknown_scenario_message(id, scenarios) do
    available = scenarios |> Map.keys() |> Enum.sort() |> Enum.join(", ")
    "unknown visual scenario #{inspect(id)}; available scenarios: #{available}"
  end

  defp capture_scenario!(scenario, output, theme) do
    File.mkdir_p!(output)

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: scenario.app(),
        args: scenario.args(theme),
        display_opts: [theme: theme]
      )

    try do
      x11_window_id = x11_window_id!(scenario.title())

      for capture <- scenario.captures() do
        run_actions(runtime, x11_window_id, Map.get(capture, :actions, []))
        capture_current!(runtime, x11_window_id, Path.join(output, capture.name <> ".bmp"))
        run_actions(runtime, x11_window_id, Map.get(capture, :after, []))
      end
    after
      if Process.alive?(runtime), do: GenServer.stop(runtime)
    end

    Mix.shell().info("Captured #{scenario.id()} visual scenario in #{output}")
  end

  defp run_actions(runtime, x11_window_id, actions) do
    Enum.each(actions, &run_action(runtime, x11_window_id, &1))
  end

  defp run_action(runtime, _x11_window_id, {:dispatch, event}) do
    {_handled, _snapshot} = GPUI.Runtime.dispatch_event(runtime, event)
    :ok
  end

  defp run_action(runtime, _x11_window_id, {:send_view, window_id, message}) do
    {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, window_id, message)
    :ok
  end

  defp run_action(runtime, _x11_window_id, {:send_view_from, window_id, build_message}) do
    assigns =
      runtime
      |> GPUI.Runtime.snapshot()
      |> Map.fetch!(:windows)
      |> Enum.find(&(&1.id == window_id))
      |> get_in([:root, :assigns])

    {:ok, _snapshot} = GPUI.Runtime.send_view(runtime, window_id, build_message.(assigns))
    :ok
  end

  defp run_action(runtime, x11_window_id, {:hover, x, y, frames}) do
    synchronize_current!(runtime, x11_window_id)
    {:ok, generation} = GPUI.Runtime.frame_token(runtime, 1)
    move_mouse!(x11_window_id, x, y)
    :ok = GPUI.Runtime.await_frame_after(runtime, 1, generation)

    if frames > 1 do
      for _frame <- 2..frames do
        {:ok, generation} = GPUI.Runtime.frame_token(runtime, 1)
        :ok = GPUI.Runtime.await_frame_after(runtime, 1, generation)
      end
    end

    :ok
  end

  defp run_action(_runtime, x11_window_id, {:move_mouse, x, y}) do
    move_mouse!(x11_window_id, x, y)
  end

  defp capture_current!(runtime, x11_window_id, path) do
    synchronize_current!(runtime, x11_window_id)
    capture!(x11_window_id, path)
  end

  defp synchronize_current!(runtime, x11_window_id) do
    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
  end

  defp move_mouse!(window_id, x, y) do
    case System.cmd(
           "xdotool",
           ["mousemove", "--sync", "--window", window_id, to_string(x), to_string(y)],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, status} -> Mix.raise("mouse move failed (#{status}): #{output}")
    end
  end

  defp request_platform_frame!(window_id) do
    case System.cmd(
           "xdotool",
           ["mousemove", "--sync", "--window", window_id, "1", "1"],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, status} -> Mix.raise("frame request failed (#{status}): #{output}")
    end
  end

  defp x11_window_id!(title) do
    case System.cmd(
           "xdotool",
           ["search", "--sync", "--onlyvisible", "--name", "^#{title}$"],
           stderr_to_stdout: true
         ) do
      {output, 0} -> output |> String.split() |> List.first()
      {output, status} -> Mix.raise("window lookup failed (#{status}): #{output}")
    end
  end

  defp capture!(window_id, path) do
    manifest =
      Path.join(@project_root, "test/support/desktop/drivers/linux/Cargo.toml")

    args = [
      "run",
      "--quiet",
      "--manifest-path",
      manifest,
      "--",
      "capture-window",
      window_id,
      path
    ]

    case System.cmd("cargo", args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> Mix.raise("capture failed (#{status}): #{output}")
    end
  end

  defp parse_theme!("dark"), do: :dark
  defp parse_theme!("light"), do: :light
  defp parse_theme!(theme), do: Mix.raise("unsupported visual capture theme: #{inspect(theme)}")

  defp ensure_executables! do
    for executable <- ~w(cargo dbus-run-session xdotool xvfb-run),
        System.find_executable(executable) == nil do
      Mix.raise("visual capture dependency not found: #{executable}")
    end
  end
end
