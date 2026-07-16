defmodule Mix.Tasks.Gpui.Visual.Capture do
  use Mix.Task

  @shortdoc "Captures synchronized native component gallery screenshots"

  defmodule GalleryView do
    use GPUI.View

    alias GPUI.UI
    alias GPUI.UI.Overlay

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col w-[640px] h-[860px] gap-4 p-4 bg-slate-900">
        <text class="text-white text-2xl font-semibold">GPUI component gallery</text>
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
  end

  defmodule GalleryApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(%{title: title}) do
      {:ok,
       [
         window title do
           size(640, 860)
           root(GalleryView, overlay: nil)
         end
       ]}
    end
  end

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args, strict: [inner: :boolean, output: :string])

    output = opts |> Keyword.get(:output, "tmp/gpui-visual") |> Path.expand()

    if opts[:inner] do
      capture_gallery(output)
    else
      run_isolated(output)
    end
  end

  defp run_isolated(output) do
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
      output
    ]

    {_output, status} =
      System.cmd("xvfb-run", args, into: IO.stream(), stderr_to_stdout: true)

    if status != 0, do: Mix.raise("visual capture failed")
  end

  defp capture_gallery(output) do
    File.mkdir_p!(output)
    title = "GPUI Visual Gallery"

    {:ok, runtime} =
      GPUI.Runtime.start_link(
        app: GalleryApp,
        args: %{title: title},
        display_opts: [theme: :dark]
      )

    try do
      window_id = x11_window_id!(title)
      capture_state!(runtime, window_id, output, "components", nil)
      capture_state!(runtime, window_id, output, "popover", "popover")
      capture_state!(runtime, window_id, output, "dialog", "dialog")
      capture_state!(runtime, window_id, output, "dropdown-menu", "menu")
    after
      if Process.alive?(runtime), do: GenServer.stop(runtime)
    end

    Mix.shell().info("Captured synchronized visual review images in #{output}")
  end

  defp capture_state!(runtime, x11_window_id, output, name, nil) do
    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
    capture!(x11_window_id, Path.join(output, "#{name}.bmp"))
  end

  defp capture_state!(runtime, x11_window_id, output, name, overlay) do
    GPUI.Runtime.dispatch_event(runtime, %{
      type: :change,
      window_id: 1,
      event: "show_overlay",
      value: overlay
    })

    request_platform_frame!(x11_window_id)
    :ok = GPUI.Runtime.await_frame(runtime, 1)
    capture!(x11_window_id, Path.join(output, "#{name}.bmp"))
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

  defp ensure_executables! do
    for executable <- ~w(cargo dbus-run-session xdotool xvfb-run),
        System.find_executable(executable) == nil do
      Mix.raise("visual capture dependency not found: #{executable}")
    end
  end
end
