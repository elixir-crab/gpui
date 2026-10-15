defmodule GPUI.Test.Native.TerminalTest do
  use GPUI.Test, native: [size: {480, 240}]

  defmodule View do
    use GPUI.View

    def render(assigns) do
      GPUI.Terminal.surface(%{
        id: "terminal",
        label: "Console",
        columns: 40,
        rows: Map.get(assigns, :rows, [[%{text: "remote$ ", columns: 8}]]),
        cursor_column: 8,
        focus_request: 1,
        disabled: Map.get(assigns, :disabled, false),
        style: [width: {:px, 480}, height: {:px, 240}],
        "phx-keystroke": "key",
        "phx-text": "text",
        "phx-paste": "paste",
        "phx-resize": "size",
        "phx-range": "visible"
      })
    end
  end

  test "typing is committed text, not a cumulative local command buffer", %{ui: ui} do
    render(ui, View, %{})
    settle(ui)
    focus(ui, "terminal")
    type(ui, "abc")

    for text <- ["a", "b", "c"] do
      assert_receive {:gpui, ^ui, {:event, %{type: :text, event: "text", value: ^text}}}
    end

    press(ui, "up")
    assert_receive {:gpui, ^ui, {:event, %{type: :keystroke, value: %{key: "up"}}}}
    type(ui, "界")
    assert_receive {:gpui, ^ui, {:event, %{type: :text, value: "界"}}}
    refute_receive {:gpui, ^ui, {:event, %{type: :text, value: "abc界"}}}
  end

  test "backspace, delete, arrows, Enter and control/meta chords carry modifiers", %{ui: ui} do
    render(ui, View, %{})
    settle(ui)
    focus(ui, "terminal")

    for key <- ["backspace", "delete", "left", "enter"] do
      press(ui, key)
      assert_receive {:gpui, ^ui, {:event, %{type: :keystroke, value: %{key: ^key}}}}
    end

    press(ui, "ctrl-c")
    assert_receive {:gpui, ^ui, {:event, %{type: :keystroke, value: %{key: "c", control: true}}}}
    press(ui, "alt-b")
    assert_receive {:gpui, ^ui, {:event, %{type: :keystroke, value: %{key: "b", alt: true}}}}
    refute_receive {:gpui, ^ui, {:event, %{type: :text}}}
  end

  test "viewport dimensions come from measured cells", %{ui: ui} do
    render(ui, View, %{})
    settle(ui)
    assert_receive {:gpui, ^ui, {:event, %{type: :resize, value: size}}}
    viewport = bounds(ui, "terminal")
    assert size.cell_width > 0
    assert size.cell_height == 20
    assert size.columns == min(512, trunc(viewport.width / size.cell_width))
    assert size.rows == min(256, trunc(viewport.height / size.cell_height))
  end

  test "styled cells cross the same native style boundary as ordinary text", %{ui: ui} do
    render(ui, View,
      rows: [
        [
          %{
            text: "ready",
            columns: 5,
            color: {:rgb, 0x00FF00},
            background: {:rgb, 0x19191E},
            font_weight: "bold",
            font_style: "italic"
          }
        ]
      ]
    )

    settle(ui)
    assert bounds(ui, "terminal").width == 480
  end

  test "disabled and restored surfaces complete frames without losing their input identity", %{
    ui: ui
  } do
    render(ui, View, %{})
    settle(ui)

    for _ <- 1..5 do
      render(ui, View, disabled: true)
      settle(ui)
      focus(ui, "terminal")
      type(ui, "ignored")
      refute_receive {:gpui, ^ui, {:event, %{type: :text}}}
      render(ui, View, disabled: false)
      settle(ui)
      focus(ui, "terminal")
      type(ui, "z")
      assert_receive {:gpui, ^ui, {:event, %{type: :text, value: "z"}}}
    end
  end

  defmodule ClipboardView do
    use GPUI.View
    alias GPUI.UI

    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col gap-2 w-[480px] h-[340px]">
        {GPUI.Test.Native.TerminalTest.View.render(assigns)}
        <UI.button id="seed" label="Seed test clipboard" clipboard_text={"first\nsecond"}
          phx-clipboard-write="seeded" />
        <UI.button id="read" label="Read test clipboard" phx-clipboard-read="read" />
      </div>
      """
    end
  end

  test "clipboard paste preserves multiline text without emitting ordinary text twice", %{ui: ui} do
    render(ui, ClipboardView, %{})
    settle(ui)
    click(ui, "seed")
    assert_receive {:gpui, ^ui, {:event, %{event: "seeded"}}}
    focus(ui, "terminal")
    press(ui, "cmd-v")
    assert_receive {:gpui, ^ui, {:event, %{type: :paste, value: "first\nsecond"}}}
    refute_receive {:gpui, ^ui, {:event, %{type: :text}}}
  end

  test "native selection copies retained rows without cursor decorations", %{ui: ui} do
    render(ui, ClipboardView,
      rows: [
        [%{text: "first", columns: 5}],
        [%{text: "界", columns: 2}, %{text: "x", columns: 1}]
      ]
    )

    settle(ui)
    focus(ui, "terminal")
    press(ui, "cmd-a")
    press(ui, "cmd-c")
    click(ui, "read")
    assert_receive {:gpui, ^ui, {:event, %{type: :clipboard, value: %{text: "first\n界x"}}}}
  end

  test "scrollback stays put until input returns it to the tail", %{ui: ui} do
    rows =
      for n <- 1..50 do
        text = "line #{n}"
        [%{text: text, columns: byte_size(text)}]
      end

    render(ui, View, rows: rows)
    settle(ui)
    focus(ui, "terminal")
    assert_receive {:gpui, ^ui, {:event, %{type: :range, value: %{first: 38, last: 50}}}}
    press(ui, "shift-pageup")
    assert_receive {:gpui, ^ui, {:event, %{type: :range, value: %{first: 27, last: 39}}}}
    type(ui, "x")
    assert_receive {:gpui, ^ui, {:event, %{type: :text, value: "x"}}}
    assert_receive {:gpui, ^ui, {:event, %{type: :range, value: %{first: 38, last: 50}}}}
  end
end
