defmodule GPUI.Native.RichTextE2ETest do
  use GPUI.Test, desktop: true

  @moduletag :e2e
  @moduletag timeout: 30_000

  defmodule RichTextView do
    use GPUI.View

    alias GPUI.Text.{Position, Range, RichRun}
    alias GPUI.UI

    @impl GPUI.View
    def render(assigns) do
      runs = [
        RichRun.new(Range.new(Position.new(0, 0), Position.new(0, 5)),
          color: 0xF8FAFC,
          font_weight: :bold,
          link: "message://hello"
        ),
        RichRun.new(Range.new(Position.new(1, 0), Position.new(1, 11)),
          color: 0x60A5FA,
          underline: 0x60A5FA,
          link: "message://details"
        )
      ]

      ~GPUI"""
      <div class="w-[480px] h-[260px] p-6 bg-slate-950 text-white">
        <UI.rich_text
          id="rich-message"
          label="Rich message"
          text={"Hello world\nOpen details"}
          runs={runs}
          phx-link="link-opened"
          class="w-[420px] text-lg leading-7 text-slate-300"
        />
        <UI.input
          id="clipboard-probe"
          label="Clipboard probe"
          value={assigns.clipboard}
          phx-change="clipboard-changed"
          class="mt-4 w-[420px]"
        />
        <text class="mt-6 text-white">Links: {assigns.links}; Last: {assigns.last_link || "none"}</text>
      </div>
      """
    end

    @impl GPUI.View
    def handle_event("link-opened", %{type: :link, value: link}, assigns),
      do: {:noreply, %{assigns | links: assigns.links + 1, last_link: link}}

    def handle_event("clipboard-changed", %{value: clipboard}, assigns),
      do: {:noreply, %{assigns | clipboard: clipboard}}
  end

  defmodule RichTextApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok,
       [
         window "GPUI Rich Text E2E" do
           size(480, 260)
           root(RichTextView, links: 0, last_link: nil, clipboard: "")
         end
       ]}
    end
  end

  test "desktop renders shaped rich text", %{desktop: desktop} do
    runtime =
      start_runtime!(desktop,
        app: RichTextApp,
        poll_interval: 10,
        display_opts: [theme: :dark]
      )

    window = Desktop.window!(desktop, "GPUI Rich Text E2E")
    Desktop.await_frame!(desktop, runtime, 1, window)
    Desktop.capture_fixture!(desktop, window, "rich-text")
    assert Process.alive?(runtime)
  end
end
