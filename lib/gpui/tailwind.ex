defmodule GPUI.Tailwind do
  @moduledoc """
  Small Tailwind-compatible class normalizer for GPUI element styles.

  This intentionally starts with a constrained subset that maps cleanly to GPUI.
  Unknown classes are preserved under `:class` by callers for future handling.
  """

  @spacing_scale %{
    "0" => 0.0,
    "1" => 4.0,
    "2" => 8.0,
    "3" => 12.0,
    "4" => 16.0,
    "5" => 20.0,
    "6" => 24.0,
    "8" => 32.0,
    "10" => 40.0,
    "12" => 48.0
  }

  @colors %{
    "black" => {:rgb, 0x000000},
    "white" => {:rgb, 0xFFFFFF},
    "neutral-700" => {:rgb, 0x404040},
    "neutral-800" => {:rgb, 0x262626},
    "slate-700" => {:rgb, 0x334155},
    "slate-800" => {:rgb, 0x1E293B},
    "slate-900" => {:rgb, 0x0F172A},
    "red-500" => {:rgb, 0xEF4444},
    "red-600" => {:rgb, 0xDC2626},
    "green-500" => {:rgb, 0x22C55E},
    "green-600" => {:rgb, 0x16A34A},
    "blue-500" => {:rgb, 0x3B82F6},
    "blue-600" => {:rgb, 0x2563EB},
    "blue-700" => {:rgb, 0x1D4ED8},
    "yellow-500" => {:rgb, 0xEAB308}
  }

  @text_sizes %{
    "xs" => 12.0,
    "sm" => 14.0,
    "base" => 16.0,
    "lg" => 18.0,
    "xl" => 20.0,
    "2xl" => 24.0,
    "3xl" => 30.0
  }

  @type result :: %{style: keyword(), unknown: [String.t()]}

  @spec normalize(String.t() | [String.t()] | nil) :: result()
  def normalize(nil), do: %{style: [], unknown: []}

  def normalize(classes) when is_list(classes) do
    classes
    |> Enum.join(" ")
    |> normalize()
  end

  def normalize(classes) when is_binary(classes) do
    classes
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce(%{style: [], unknown: []}, &normalize_class/2)
    |> Map.update!(:style, &Enum.reverse/1)
    |> Map.update!(:unknown, &Enum.reverse/1)
  end

  defp normalize_class("flex", acc), do: put_style(acc, :display, :flex)
  defp normalize_class("flex-col", acc), do: put_style(acc, :flex_direction, :column)
  defp normalize_class("flex-row", acc), do: put_style(acc, :flex_direction, :row)
  defp normalize_class("items-center", acc), do: put_style(acc, :align_items, :center)
  defp normalize_class("items-start", acc), do: put_style(acc, :align_items, :start)
  defp normalize_class("items-end", acc), do: put_style(acc, :align_items, :end)
  defp normalize_class("justify-center", acc), do: put_style(acc, :justify_content, :center)
  defp normalize_class("justify-start", acc), do: put_style(acc, :justify_content, :start)
  defp normalize_class("justify-end", acc), do: put_style(acc, :justify_content, :end)
  defp normalize_class("font-bold", acc), do: put_style(acc, :font_weight, :bold)
  defp normalize_class("border", acc), do: put_style(acc, :border_width, {:px, 1.0})

  defp normalize_class("rounded" <> suffix, acc) do
    radius =
      if suffix == "", do: {:px, 4.0}, else: rounded_radius(String.trim_leading(suffix, "-"))

    put_style(acc, :border_radius, radius)
  end

  defp normalize_class("gap-" <> value, acc), do: spacing(acc, :gap, value)
  defp normalize_class("p-" <> value, acc), do: spacing(acc, :padding, value)
  defp normalize_class("m-" <> value, acc), do: spacing(acc, :margin, value)
  defp normalize_class("w-" <> value, acc), do: length_value(acc, :width, value)
  defp normalize_class("h-" <> value, acc), do: length_value(acc, :height, value)

  defp normalize_class("size-" <> value, acc) do
    case parse_length(value) do
      {:ok, length} -> acc |> put_style(:width, length) |> put_style(:height, length)
      :error -> unknown(acc, "size-#{value}")
    end
  end

  defp normalize_class("bg-" <> color, acc), do: color(acc, :background, color, "bg-")
  defp normalize_class("text-" <> size_or_color, acc), do: text(size_or_color, acc)
  defp normalize_class(class, acc), do: unknown(acc, class)

  defp text(value, acc) do
    cond do
      Map.has_key?(@text_sizes, value) ->
        put_style(acc, :font_size, {:px, Map.fetch!(@text_sizes, value)})

      Map.has_key?(@colors, value) ->
        put_style(acc, :color, Map.fetch!(@colors, value))

      true ->
        unknown(acc, "text-#{value}")
    end
  end

  defp color(acc, key, value, prefix) do
    case Map.fetch(@colors, value) do
      {:ok, color} -> put_style(acc, key, color)
      :error -> unknown(acc, prefix <> value)
    end
  end

  defp spacing(acc, key, value) do
    case Map.fetch(@spacing_scale, value) do
      {:ok, px} -> put_style(acc, key, {:px, px})
      :error -> unknown(acc, "#{key}-#{value}")
    end
  end

  defp length_value(acc, key, value) do
    case parse_length(value) do
      {:ok, length} -> put_style(acc, key, length)
      :error -> unknown(acc, "#{key}-#{value}")
    end
  end

  defp parse_length("[" <> rest) do
    with value when value != rest <- String.trim_trailing(rest, "]"),
         {:ok, number} <- parse_px(value) do
      {:ok, {:px, number}}
    else
      _ -> :error
    end
  end

  defp parse_length(value) do
    case Map.fetch(@spacing_scale, value) do
      {:ok, px} -> {:ok, {:px, px}}
      :error -> :error
    end
  end

  defp parse_px(value) do
    value = String.trim_trailing(value, "px")

    case Float.parse(value) do
      {number, ""} -> {:ok, number}
      _ -> :error
    end
  end

  defp rounded_radius("none"), do: {:px, 0.0}
  defp rounded_radius("sm"), do: {:px, 2.0}
  defp rounded_radius("md"), do: {:px, 6.0}
  defp rounded_radius("lg"), do: {:px, 8.0}
  defp rounded_radius("full"), do: :full
  defp rounded_radius(_), do: {:px, 4.0}

  defp put_style(acc, key, value),
    do: update_in(acc.style, &[{key, value} | Keyword.delete(&1, key)])

  defp unknown(acc, class), do: update_in(acc.unknown, &[class | &1])
end
