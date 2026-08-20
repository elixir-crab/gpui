defmodule GPUI.Native.RichTextE2ETest do
  use ExUnit.Case, async: false

  alias GPUITest.Desktop

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
      <div class="w-[480px] h-[260px] p-6 bg-slate-950">
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

  test "shapes rich runs, activates links, selects text, and copies" do
    {:ok, runtime} = GPUI.Runtime.start_link(app: RichTextApp, poll_interval: 10)
    on_exit(fn -> Desktop.stop_process(runtime) end)
    assert :ok = GPUI.Runtime.subscribe(runtime)

    native_window_id = Desktop.window_id!("GPUI Rich Text E2E")
    Desktop.await_frame!(runtime, 1, native_window_id)

    Desktop.click!(native_window_id, 80, 62)

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [
                        %{type: :link, event: "link-opened", value: "message://details"}
                      ]
                    }}

    Desktop.key!(native_window_id, "Left")
    Desktop.key!(native_window_id, "Return")

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [
                        %{type: :link, event: "link-opened", value: "message://hello"}
                      ]
                    }}

    Desktop.key!(native_window_id, "Right")
    Desktop.key!(native_window_id, "space")

    assert_receive {:gpui, ^runtime,
                    %GPUI.Runtime.Update{
                      events: [
                        %{type: :link, event: "link-opened", value: "message://details"}
                      ]
                    }}

    Desktop.key!(native_window_id, "ctrl+a")
    Desktop.key!(native_window_id, "ctrl+c")
    Desktop.click!(native_window_id, 120, 108)
    Desktop.key!(native_window_id, "ctrl+v")

    Desktop.eventually(fn ->
      assigns = runtime |> GPUI.Runtime.snapshot() |> hd_window_assigns()
      assert assigns.clipboard == "Hello world\nOpen details"
    end)

    Desktop.click!(native_window_id, 32, 34)
    Desktop.drag!(native_window_id, 32, 34, 125, 34)
    Desktop.key!(native_window_id, "ctrl+c")
    Desktop.click!(native_window_id, 120, 108)
    Desktop.key!(native_window_id, "ctrl+a")
    Desktop.key!(native_window_id, "ctrl+v")

    Desktop.eventually(fn ->
      assigns = runtime |> GPUI.Runtime.snapshot() |> hd_window_assigns()
      assert assigns.clipboard != ""
      assert String.contains?("Hello world", assigns.clipboard)
    end)

    assert Process.alive?(runtime)
  end

  defp hd_window_assigns(snapshot),
    do: snapshot.windows |> hd() |> get_in([:root, :assigns])
end
