defmodule GPUI.Tailwind do
  @moduledoc """
  Small Tailwind-compatible class normalizer for GPUI element styles.

  This intentionally starts with a constrained subset that maps cleanly to GPUI.
  Unknown classes are preserved under `:class` by callers for future handling.
  """

  @spacing_unit 4.0

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

  @line_heights %{
    "none" => 16.0,
    "tight" => 20.0,
    "snug" => 22.0,
    "normal" => 24.0,
    "relaxed" => 26.0,
    "loose" => 32.0
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

  defp normalize_class("flex-1", acc), do: put_style(acc, :flex, :one)
  defp normalize_class("flex-auto", acc), do: put_style(acc, :flex, :auto)
  defp normalize_class("flex-initial", acc), do: put_style(acc, :flex, :initial)
  defp normalize_class("flex-none", acc), do: put_style(acc, :flex, :none)
  defp normalize_class("flex", acc), do: put_style(acc, :display, :flex)
  defp normalize_class("block", acc), do: put_style(acc, :display, :block)
  defp normalize_class("grid", acc), do: put_style(acc, :display, :grid)
  defp normalize_class("hidden", acc), do: put_style(acc, :display, :none)
  defp normalize_class("flex-col", acc), do: put_style(acc, :flex_direction, :column)

  defp normalize_class("flex-col-reverse", acc),
    do: put_style(acc, :flex_direction, :column_reverse)

  defp normalize_class("flex-row", acc), do: put_style(acc, :flex_direction, :row)
  defp normalize_class("flex-row-reverse", acc), do: put_style(acc, :flex_direction, :row_reverse)
  defp normalize_class("flex-wrap", acc), do: put_style(acc, :flex_wrap, :wrap)
  defp normalize_class("flex-wrap-reverse", acc), do: put_style(acc, :flex_wrap, :wrap_reverse)
  defp normalize_class("flex-nowrap", acc), do: put_style(acc, :flex_wrap, :nowrap)
  defp normalize_class("basis-auto", acc), do: put_style(acc, :flex_basis, :auto)
  defp normalize_class("basis-" <> value, acc), do: length_value(acc, :flex_basis, value)
  defp normalize_class("grow", acc), do: put_style(acc, :flex_grow, 1.0)
  defp normalize_class("grow-0", acc), do: put_style(acc, :flex_grow, 0.0)
  defp normalize_class("shrink", acc), do: put_style(acc, :flex_shrink, 1.0)
  defp normalize_class("shrink-0", acc), do: put_style(acc, :flex_shrink, 0.0)
  defp normalize_class("items-center", acc), do: put_style(acc, :align_items, :center)
  defp normalize_class("items-start", acc), do: put_style(acc, :align_items, :start)
  defp normalize_class("items-end", acc), do: put_style(acc, :align_items, :end)
  defp normalize_class("items-baseline", acc), do: put_style(acc, :align_items, :baseline)
  defp normalize_class("items-stretch", acc), do: put_style(acc, :align_items, :stretch)
  defp normalize_class("justify-center", acc), do: put_style(acc, :justify_content, :center)
  defp normalize_class("justify-start", acc), do: put_style(acc, :justify_content, :start)
  defp normalize_class("justify-end", acc), do: put_style(acc, :justify_content, :end)
  defp normalize_class("justify-between", acc), do: put_style(acc, :justify_content, :between)
  defp normalize_class("justify-around", acc), do: put_style(acc, :justify_content, :around)
  defp normalize_class("justify-evenly", acc), do: put_style(acc, :justify_content, :evenly)
  defp normalize_class("overflow-hidden", acc), do: put_style(acc, :overflow, :hidden)
  defp normalize_class("whitespace-normal", acc), do: put_style(acc, :white_space, :normal)
  defp normalize_class("whitespace-nowrap", acc), do: put_style(acc, :white_space, :nowrap)
  defp normalize_class("text-ellipsis", acc), do: put_style(acc, :text_overflow, :ellipsis)
  defp normalize_class("text-left", acc), do: put_style(acc, :text_align, :left)
  defp normalize_class("text-center", acc), do: put_style(acc, :text_align, :center)
  defp normalize_class("text-right", acc), do: put_style(acc, :text_align, :right)
  defp normalize_class("truncate", acc), do: put_style(acc, :truncate, true)
  defp normalize_class("cursor-default", acc), do: put_style(acc, :cursor, :default)
  defp normalize_class("cursor-pointer", acc), do: put_style(acc, :cursor, :pointer)
  defp normalize_class("cursor-text", acc), do: put_style(acc, :cursor, :text)
  defp normalize_class("cursor-move", acc), do: put_style(acc, :cursor, :move)
  defp normalize_class("cursor-not-allowed", acc), do: put_style(acc, :cursor, :not_allowed)
  defp normalize_class("font-light", acc), do: put_style(acc, :font_weight, :light)
  defp normalize_class("font-normal", acc), do: put_style(acc, :font_weight, :normal)
  defp normalize_class("font-medium", acc), do: put_style(acc, :font_weight, :medium)
  defp normalize_class("font-semibold", acc), do: put_style(acc, :font_weight, :semibold)
  defp normalize_class("font-bold", acc), do: put_style(acc, :font_weight, :bold)
  defp normalize_class("border", acc), do: put_style(acc, :border_width, {:px, 1.0})
  defp normalize_class("border-" <> color, acc), do: color(acc, :border_color, color, "border-")

  defp normalize_class("rounded" <> suffix = class, acc) do
    radius =
      if suffix == "",
        do: {:ok, {:px, 4.0}},
        else: rounded_radius(String.trim_leading(suffix, "-"))

    case radius do
      {:ok, value} -> put_style(acc, :border_radius, value)
      :error -> unknown(acc, class)
    end
  end

  defp normalize_class("gap-" <> value, acc), do: spacing(acc, :gap, value)
  defp normalize_class("p-" <> value, acc), do: spacing(acc, :padding, value)
  defp normalize_class("px-" <> value, acc), do: spacing(acc, :padding_x, value)
  defp normalize_class("py-" <> value, acc), do: spacing(acc, :padding_y, value)
  defp normalize_class("pt-" <> value, acc), do: spacing(acc, :padding_top, value)
  defp normalize_class("pr-" <> value, acc), do: spacing(acc, :padding_right, value)
  defp normalize_class("pb-" <> value, acc), do: spacing(acc, :padding_bottom, value)
  defp normalize_class("pl-" <> value, acc), do: spacing(acc, :padding_left, value)
  defp normalize_class("m-" <> value, acc), do: spacing(acc, :margin, value)
  defp normalize_class("mx-" <> value, acc), do: spacing(acc, :margin_x, value)
  defp normalize_class("my-" <> value, acc), do: spacing(acc, :margin_y, value)
  defp normalize_class("mt-" <> value, acc), do: spacing(acc, :margin_top, value)
  defp normalize_class("mr-" <> value, acc), do: spacing(acc, :margin_right, value)
  defp normalize_class("mb-" <> value, acc), do: spacing(acc, :margin_bottom, value)
  defp normalize_class("ml-" <> value, acc), do: spacing(acc, :margin_left, value)
  defp normalize_class("w-" <> value, acc), do: length_value(acc, :width, value)
  defp normalize_class("h-" <> value, acc), do: length_value(acc, :height, value)
  defp normalize_class("min-w-" <> value, acc), do: length_value(acc, :min_width, value)
  defp normalize_class("max-w-" <> value, acc), do: length_value(acc, :max_width, value)
  defp normalize_class("min-h-" <> value, acc), do: length_value(acc, :min_height, value)
  defp normalize_class("max-h-" <> value, acc), do: length_value(acc, :max_height, value)

  defp normalize_class("size-" <> value, acc) do
    case parse_length(value) do
      {:ok, length} -> acc |> put_style(:width, length) |> put_style(:height, length)
      :error -> unknown(acc, "size-#{value}")
    end
  end

  defp normalize_class("bg-" <> color, acc), do: color(acc, :background, color, "bg-")
  defp normalize_class("text-" <> size_or_color, acc), do: text(size_or_color, acc)
  defp normalize_class("leading-" <> value, acc), do: line_height(value, acc)
  defp normalize_class("opacity-" <> value, acc), do: opacity(value, acc)
  defp normalize_class(class, acc), do: unknown(acc, class)

  defp text(value, acc) do
    cond do
      Map.has_key?(@text_sizes, value) ->
        put_style(acc, :font_size, {:px, Map.fetch!(@text_sizes, value)})

      match?({:ok, _value}, parse_arbitrary_px(value)) ->
        {:ok, px} = parse_arbitrary_px(value)
        put_style(acc, :font_size, {:px, px})

      true ->
        color(acc, :color, value, "text-")
    end
  end

  defp line_height(value, acc) do
    case {Map.fetch(@line_heights, value), parse_arbitrary_px(value)} do
      {{:ok, px}, _arbitrary} -> put_style(acc, :line_height, {:px, px})
      {:error, {:ok, px}} -> put_style(acc, :line_height, {:px, px})
      {:error, :error} -> unknown(acc, "leading-#{value}")
    end
  end

  defp opacity("[" <> _rest = value, acc) do
    case parse_arbitrary_number(value) do
      {:ok, opacity} when opacity >= 0.0 and opacity <= 1.0 ->
        put_style(acc, :opacity, opacity)

      _other ->
        unknown(acc, "opacity-#{value}")
    end
  end

  defp opacity(value, acc) do
    case Integer.parse(value) do
      {opacity, ""} when opacity in 0..100 -> put_style(acc, :opacity, opacity / 100)
      _other -> unknown(acc, "opacity-#{value}")
    end
  end

  defp color(acc, key, value, prefix) do
    case Map.fetch(@colors, value) do
      {:ok, color} -> put_style(acc, key, color)
      :error -> arbitrary_color(acc, key, value, prefix)
    end
  end

  defp arbitrary_color(acc, key, "[#" <> rest = value, prefix) do
    with hex when hex != rest <- String.trim_trailing(rest, "]"),
         6 <- byte_size(hex),
         {rgb, ""} <- Integer.parse(hex, 16) do
      put_style(acc, key, {:rgb, rgb})
    else
      _other -> unknown(acc, prefix <> value)
    end
  end

  defp arbitrary_color(acc, _key, value, prefix), do: unknown(acc, prefix <> value)

  defp spacing(acc, key, value) do
    case parse_spacing(value) do
      {:ok, px} -> put_style(acc, key, {:px, px})
      :error -> unknown(acc, class_name(key, value))
    end
  end

  defp length_value(acc, key, value) do
    case parse_length(value) do
      {:ok, length} -> put_style(acc, key, length)
      :error -> unknown(acc, class_name(key, value))
    end
  end

  defp class_name(key, value) do
    prefix =
      %{
        gap: "gap",
        padding: "p",
        padding_x: "px",
        padding_y: "py",
        padding_top: "pt",
        padding_right: "pr",
        padding_bottom: "pb",
        padding_left: "pl",
        margin: "m",
        margin_x: "mx",
        margin_y: "my",
        margin_top: "mt",
        margin_right: "mr",
        margin_bottom: "mb",
        margin_left: "ml",
        flex_basis: "basis",
        width: "w",
        height: "h",
        min_width: "min-w",
        max_width: "max-w",
        min_height: "min-h",
        max_height: "max-h"
      }
      |> Map.fetch!(key)

    "#{prefix}-#{value}"
  end

  defp parse_length("full"), do: {:ok, :full}

  defp parse_length("[" <> _rest = value) do
    case parse_arbitrary(value) do
      {:ok, {:px, number}} -> {:ok, {:px, number}}
      {:ok, {:percent, percentage}} -> {:ok, {:fraction, percentage / 100}}
      :error -> :error
    end
  end

  defp parse_length(value) do
    case parse_fraction(value) do
      {:ok, fraction} -> {:ok, {:fraction, fraction}}
      :error -> parse_spacing_length(value)
    end
  end

  defp parse_spacing_length(value) do
    case parse_spacing(value) do
      {:ok, px} -> {:ok, {:px, px}}
      :error -> :error
    end
  end

  defp parse_spacing(value) do
    case Float.parse(value) do
      {number, ""} when number >= 0.0 -> {:ok, number * @spacing_unit}
      _other -> parse_arbitrary_px(value)
    end
  end

  defp parse_fraction(value) do
    case String.split(value, "/", parts: 2) do
      [numerator, denominator] ->
        with {numerator, ""} <- Float.parse(numerator),
             {denominator, ""} when denominator > 0.0 <- Float.parse(denominator),
             fraction when fraction >= 0.0 and fraction <= 1.0 <- numerator / denominator do
          {:ok, fraction}
        else
          _other -> :error
        end

      _other ->
        :error
    end
  end

  defp parse_arbitrary_px(value) do
    case parse_arbitrary(value) do
      {:ok, {:px, px}} -> {:ok, px}
      _other -> :error
    end
  end

  defp parse_arbitrary_number("[" <> rest) do
    with value when value != rest <- String.trim_trailing(rest, "]"),
         {number, ""} <- Float.parse(value) do
      {:ok, number}
    else
      _other -> :error
    end
  end

  defp parse_arbitrary_number(_value), do: :error

  defp parse_arbitrary("[" <> rest) do
    case String.trim_trailing(rest, "]") do
      ^rest ->
        :error

      value ->
        cond do
          String.ends_with?(value, "px") -> parse_unit(value, "px", :px)
          String.ends_with?(value, "%") -> parse_unit(value, "%", :percent)
          true -> :error
        end
    end
  end

  defp parse_arbitrary(_value), do: :error

  defp parse_unit(value, suffix, unit) do
    value = String.trim_trailing(value, suffix)

    case Float.parse(value) do
      {number, ""} -> {:ok, {unit, number}}
      _other -> :error
    end
  end

  defp rounded_radius("[" <> _rest = value) do
    case parse_arbitrary_px(value) do
      {:ok, px} -> {:ok, {:px, px}}
      :error -> :error
    end
  end

  defp rounded_radius("none"), do: {:ok, {:px, 0.0}}
  defp rounded_radius("sm"), do: {:ok, {:px, 2.0}}
  defp rounded_radius("md"), do: {:ok, {:px, 6.0}}
  defp rounded_radius("lg"), do: {:ok, {:px, 8.0}}
  defp rounded_radius("full"), do: {:ok, :full}
  defp rounded_radius(value) when value in ["", "DEFAULT"], do: {:ok, {:px, 4.0}}
  defp rounded_radius(_value), do: :error

  defp put_style(acc, key, value),
    do: update_in(acc.style, &[{key, value} | Keyword.delete(&1, key)])

  defp unknown(acc, class), do: update_in(acc.unknown, &[class | &1])
end
