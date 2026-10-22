defmodule GPUI.Terminal do
  @moduledoc """
  A native fixed-cell display and input boundary for application-owned terminals.

  GPUI does not parse escape sequences, open a PTY, or edit a remote command line.
  Pass retained rows (oldest first), with each run declaring its terminal-column
  width. The last visible rows follow the tail until the user scrolls. Mouse
  selection and platform copy/paste remain native. `phx-text` emits committed
  text, `phx-paste` preserves clipboard newlines, and `phx-keystroke` emits
  logical keys with modifiers; do not forward printable keys a second time.

  Row runs accept `text`, `columns`, and ordinary text style keys `color`,
  `background`, `font_weight`, and `font_style`. Split wide/fallback glyphs into
  their own runs to preserve exact grid placement. Cursor coordinates address
  retained rows, not pixels. `reset_request` clears selection/scroll on session
  changes; `focus_request` requests focus without recreating the surface.
  """
  alias GPUI.{Element, Schema}
  @max_rows 10_000
  @max_columns 512
  @max_bytes 8 * 1024 * 1024
  @style_keys ~w(color background font_weight font_style)a

  @doc "Builds a bounded terminal surface from application-owned cell runs."
  @spec surface(map()) :: Element.t()
  def surface(assigns) do
    {rows, attrs} = Map.pop(assigns, :rows, [])
    columns = Map.get(attrs, :columns, 80)

    unless is_integer(columns) and columns in 1..@max_columns and
             is_list(rows) and length(rows) <= @max_rows do
      raise ArgumentError, "terminal allows 1–512 columns and at most 10000 retained rows"
    end

    children = Enum.map(rows, &row(&1, columns))

    bytes =
      Enum.reduce(rows, 0, fn runs, size ->
        Enum.reduce(runs, size, &(byte_size(&1.text) + &2))
      end)

    if bytes > @max_bytes, do: raise(ArgumentError, "terminal text exceeds 8 MiB")

    attrs =
      attrs
      |> Schema.apply_defaults(:ui_terminal)
      |> Schema.validate_component_assigns!(:ui_terminal)

    %Element{type: :ui_terminal, attrs: Map.to_list(attrs), children: children}
  end

  defp row(runs, columns) when is_list(runs) do
    {children, used} =
      Enum.map_reduce(runs, 0, fn run, used ->
        unless is_map(run), do: raise(ArgumentError, "terminal runs must be maps")
        text = Map.get(run, :text)
        width = Map.get(run, :columns)

        unless is_binary(text) and String.valid?(text) and byte_size(text) <= 65_536 and
                 not String.match?(text, ~r/[\x00-\x1f\x7f]/u) and
                 is_integer(width) and width > 0 and used + width <= columns and
                 ((byte_size(text) == width and String.match?(text, ~r/\A[\x20-\x7e]+\z/)) or
                    (match?({_, ""}, String.next_grapheme(text)) and width in [1, 2])) and
                 Map.keys(run) -- [:text, :columns | @style_keys] == [] do
          raise ArgumentError, "terminal runs require bounded single-line text and column spans"
        end

        cell = %Element{
          type: :ui_terminal_cell,
          attrs: [
            text: text,
            columns: width,
            italic: Map.get(run, :font_style) in [:italic, "italic"],
            style: cell_style(run)
          ]
        }

        {cell, used + width}
      end)

    _ = used
    %Element{type: :ui_terminal_row, children: children}
  end

  defp row(_, _), do: raise(ArgumentError, "terminal rows must be lists of runs")

  defp cell_style(run) do
    weight =
      case Map.get(run, :font_weight, :normal) do
        weight when weight in [:normal, "normal"] -> :normal
        weight when weight in [:bold, "bold"] -> :bold
        _ -> raise ArgumentError, "terminal font_weight must be normal or bold"
      end

    unless Map.get(run, :font_style, :normal) in [:normal, "normal", :italic, "italic"],
      do: raise(ArgumentError, "terminal font_style must be normal or italic")

    run |> Map.take([:color, :background]) |> Map.put(:font_weight, weight) |> Map.to_list()
  end
end
