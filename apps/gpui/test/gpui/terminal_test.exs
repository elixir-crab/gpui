defmodule GPUI.TerminalTest do
  use ExUnit.Case, async: true
  alias GPUI.{Element, Event, Terminal}

  test "terminal surface declares cells, not a second editable line buffer" do
    surface =
      Terminal.surface(%{
        id: "console",
        label: "Remote console",
        columns: 4,
        rows: [[%{text: "a", columns: 1}, %{text: "界", columns: 2, color: {:rgb, 0xFF0000}}]],
        cursor_row: 0,
        cursor_column: 3,
        "phx-keystroke": "key",
        "phx-text": "text",
        "phx-paste": "paste",
        "phx-resize": "size"
      })

    payload = Element.to_payload(surface)
    assert payload.type == :ui_terminal
    assert [%{type: :ui_terminal_row, children: cells}] = payload.children
    assert Enum.map(cells, & &1.attrs.text) == ["a", "界"]
  end

  test "bounds rows, spans and cell text before crossing the native boundary" do
    for rows <- [
          [[%{text: "x", columns: 0}]],
          [[%{text: "x\n", columns: 1}]],
          [[%{text: "x", columns: 5}]],
          List.duplicate([], 10_001)
        ] do
      assert_raise ArgumentError, fn ->
        Terminal.surface(%{id: "t", label: "Console", columns: 4, rows: rows})
      end
    end
  end

  test "raw keystrokes preserve modifiers independently of committed text and paste" do
    value = %{key: "c", control: true, alt: false, shift: false, platform: false, repeat: false}

    assert {:ok, %{value: ^value}} =
             Event.normalize(%{type: :keystroke, event: "key", window_id: 1, value: value})

    assert {:ok, %{value: "hello\nworld"}} =
             Event.normalize(%{type: :paste, event: "paste", window_id: 1, value: "hello\nworld"})

    assert {:ok, %{value: "界"}} =
             Event.normalize(%{type: :text, event: "text", window_id: 1, value: "界"})

    assert {:error, _} =
             Event.normalize(%{
               type: :keystroke,
               event: "key",
               window_id: 1,
               value: %{value | control: "true"}
             })
  end

  test "resize reports measured cells and integral PTY dimensions" do
    value = %{columns: 80, rows: 24, cell_width: 8.25, cell_height: 19.0}

    assert {:ok, %{value: ^value}} =
             Event.normalize(%{type: :resize, event: "size", window_id: 1, value: value})

    assert {:error, _} =
             Event.normalize(%{
               type: :resize,
               event: "size",
               window_id: 1,
               value: %{value | cell_width: 0}
             })
  end
end
