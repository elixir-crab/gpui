defmodule Mix.Tasks.Gpui.Visual.Capture do
  use Mix.Task

  @shortdoc "Captures synchronized native visual review screenshots"

  defmodule GalleryView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[640px] h-[860px] gap-4 p-4" style={background_style(assigns.theme)}>
        <text class="text-2xl font-semibold" style={foreground_style(assigns.theme)}>GPUI component gallery</text>
        <UI.button id="primary" label="Primary button" variant="primary" />
        <UI.checkbox id="checked" label="Checked checkbox" checked={true} />
        <UI.switch id="notifications" label="Notifications" checked={true} />
        <UI.input id="name" value="Ada Lovelace" placeholder="Name" cleanable={true} />
        <UI.select id="language" value="elixir" options={[{"Elixir", "elixir"}, {"Rust", "rust"}]} />
        <UI.combobox id="framework" value="Phoenix" options={["Phoenix", "LiveView"]} />
        <UI.radio_group
          id="plan"
          value="team"
          options={[{"Free", "free"}, {"Team", "team"}, %{label: "Pro", value: "pro", disabled: true}]}
          orientation="horizontal"
        />
        <UI.tabs
          id="section"
          value="general"
          options={[{"General", "general"}, {"Advanced", "advanced"}]}
          variant="underline"
        />
        <UI.slider id="volume" value={65} min={0} max={100} />
        <UI.accordion id="details" expanded={["account"]}>
          <UI.accordion_item id="account" title="Account">
            <text>Account details</text>
          </UI.accordion_item>
          <UI.accordion_item id="security" title="Security">
            <text>Security details</text>
          </UI.accordion_item>
        </UI.accordion>
        <Overlay.popover id="gallery-popover" open={assigns.overlay == "popover"}>
          <:trigger><UI.button id="popover-trigger" label="Popover" /></:trigger>
          <:content><text>Popover content</text></:content>
        </Overlay.popover>
        <Overlay.tooltip id="gallery-tooltip" delay={100}>
          <:trigger><UI.button id="tooltip-trigger" label="Tooltip" /></:trigger>
          <:content>Tooltip content</:content>
        </Overlay.tooltip>
        <Overlay.dialog
          id="gallery-dialog"
          open={assigns.overlay == "dialog"}
          title="Visual review dialog"
          width={360}
        >
          <:content><UI.input id="dialog-input" value="Dialog content" /></:content>
        </Overlay.dialog>
        <Overlay.dropdown_menu id="gallery-menu" open={assigns.overlay == "menu"}>
          <:trigger><UI.button id="menu-trigger" label="File menu" /></:trigger>
          <:item value="new">New file</:item>
          <:item value="recent" checked={true}>Open recent</:item>
          <:item value="delete" disabled={true}>Delete</:item>
        </Overlay.dropdown_menu>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("show_overlay", %{value: overlay}, assigns),
      do: {:noreply, %{assigns | overlay: overlay}}

    defp background_style(:dark), do: [background: {:rgb, 0x0F172A}]
    defp background_style(:light), do: [background: {:rgb, 0xFFFFFF}]
    defp foreground_style(:dark), do: [color: {:rgb, 0xFFFFFF}]
    defp foreground_style(:light), do: [color: {:rgb, 0x000000}]
  end

  defmodule GalleryApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title, theme: theme}) do
      {:ok,
       [
         window title do
           size(640, 860)
           root(GalleryView, overlay: nil, theme: theme)
         end
       ]}
    end
  end

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [inner: :boolean, output: :string, theme: :string, example: :string]
      )

    output = opts |> Keyword.get(:output, "tmp/gpui-visual") |> Path.expand()
    theme = opts |> Keyword.get(:theme, "dark") |> parse_theme!()
    target = opts |> Keyword.get(:example, "gallery") |> parse_target!()

    if opts[:inner] do
      capture_target(target, output, theme)
    else
      run_isolated(target, output, theme)
    end
  end

  defp run_isolated(target, output, theme) do
    ensure_executables!()

    args = [
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
      Atom.to_string(theme),
      "--example",
      Atom.to_string(target)
    ]

    {_output, status} =
      System.cmd("xvfb-run", args, into: IO.stream(), stderr_to_stdout: true)

    if status != 0, do: Mix.raise("visual capture failed")
  end

  defp capture_target(:gallery, output, theme), do: capture_gallery(output, theme)

  defp capture_target(:process_explorer, output, theme),
    do: capture_process_explorer(output, theme)

  defp capture_gallery(output, theme) do
    File.mkdir_p!(output)
    title = "GPUI Visual Gallery"

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: GalleryApp,
        args: %{title: title, theme: theme},
        display_opts: [theme: theme]
      )

    try do
      window_id = x11_window_id!(title)
      capture_state!(runtime, window_id, output, "components", nil)
      capture_state!(runtime, window_id, output, "popover", "popover")
      capture_tooltip!(runtime, window_id, output)
      capture_state!(runtime, window_id, output, "dialog", "dialog")
      capture_state!(runtime, window_id, output, "dropdown-menu", "menu")
    after
      if Process.alive?(runtime), do: GenServer.stop(runtime)
    end

    Mix.shell().info("Captured synchronized visual review images in #{output}")
  end

  defp capture_process_explorer(output, theme) do
    File.mkdir_p!(output)

    Code.require_file(
      Path.expand("../../../examples/process_explorer/support/process_explorer.exs", __DIR__)
    )

    title = "BEAM Process Explorer"

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: Examples.ProcessExplorer.App,
        display_opts: [theme: theme]
      )

    try do
      window_id = x11_window_id!(title)
      capture_current!(runtime, window_id, Path.join(output, "processes.bmp"))

      selected_pid =
        runtime
        |> GPUI.Runtime.snapshot()
        |> get_in([Access.key!(:windows), Access.at(0), :root, :assigns, :processes])
        |> Enum.max_by(& &1.memory)
        |> Map.fetch!(:pid)

      GPUI.Runtime.dispatch_event(runtime, %{
        type: :click,
        window_id: 1,
        event: "select:" <> selected_pid
      })

      capture_current!(runtime, window_id, Path.join(output, "selected-process.bmp"))
    after
      if Process.alive?(runtime), do: GenServer.stop(runtime)
    end

    Mix.shell().info("Captured synchronized process explorer images in #{output}")
  end

  defp capture_current!(runtime, x11_window_id, path) do
    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
    capture!(x11_window_id, path)
  end

  defp capture_state!(runtime, x11_window_id, output, name, nil) do
    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
    capture!(x11_window_id, Path.join(output, "#{name}.bmp"))
  end

  defp capture_state!(runtime, x11_window_id, output, name, overlay) do
    GPUI.Runtime.dispatch_event(runtime, show_overlay_event(overlay))

    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
    capture!(x11_window_id, Path.join(output, "#{name}.bmp"))
  end

  defp show_overlay_event(overlay) do
    %{type: :change, window_id: 1, event: "show_overlay", value: overlay}
  end

  defp capture_tooltip!(runtime, x11_window_id, output) do
    GPUI.Runtime.dispatch_event(runtime, show_overlay_event(nil))

    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
    {:ok, hover_generation} = GPUI.Runtime.frame_token(runtime, 1)
    move_mouse!(x11_window_id, 320, 666)
    :ok = GPUI.Runtime.await_frame_after(runtime, 1, hover_generation)
    {:ok, tooltip_generation} = GPUI.Runtime.frame_token(runtime, 1)
    :ok = GPUI.Runtime.await_frame_after(runtime, 1, tooltip_generation)
    capture!(x11_window_id, Path.join(output, "tooltip.bmp"))
    move_mouse!(x11_window_id, 1, 1)
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
    manifest = Path.expand("../../../test/support/e2e_driver/Cargo.toml", __DIR__)

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

  defp parse_target!("gallery"), do: :gallery
  defp parse_target!("process_explorer"), do: :process_explorer

  defp parse_target!(target),
    do: Mix.raise("unsupported visual capture example: #{inspect(target)}")

  defp ensure_executables! do
    for executable <- ~w(cargo dbus-run-session xdotool xvfb-run),
        System.find_executable(executable) == nil do
      Mix.raise("visual capture dependency not found: #{executable}")
    end
  end
end
