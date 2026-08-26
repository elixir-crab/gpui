defmodule GPUI.Color do
  @moduledoc """
  Compile-time hexadecimal RGB and RGBA color literals.

  `~RGB` accepts three or six hexadecimal digits. `~RGBA` accepts four or
  eight hexadecimal digits. Short literals expand each digit, so `~RGB"abc"`
  is equivalent to `{:rgb, 0xAABBCC}`.

  These sigils deliberately omit a leading `#` because their names already
  identify the literal as a hexadecimal color.
  """

  @type rgb :: {:rgb, 0x000000..0xFFFFFF}
  @type rgba :: {:rgba, 0x00000000..0xFFFFFFFF}
  @type t :: rgb() | rgba()

  @doc "Builds an opaque RGB literal from three or six hexadecimal digits."
  defmacro sigil_RGB({:<<>>, _meta, [literal]}, modifiers)
           when is_binary(literal) and modifiers == [] do
    Macro.escape({:rgb, parse_hex!(literal, [3, 6], "RGB", __CALLER__)})
  end

  defmacro sigil_RGB(_literal, _modifiers),
    do: invalid_literal!("RGB", "three or six hexadecimal digits", __CALLER__)

  @doc "Builds an RGBA literal from four or eight hexadecimal digits."
  defmacro sigil_RGBA({:<<>>, _meta, [literal]}, modifiers)
           when is_binary(literal) and modifiers == [] do
    Macro.escape({:rgba, parse_hex!(literal, [4, 8], "RGBA", __CALLER__)})
  end

  defmacro sigil_RGBA(_literal, _modifiers),
    do: invalid_literal!("RGBA", "four or eight hexadecimal digits", __CALLER__)

  defp parse_hex!(literal, lengths, name, caller) do
    expanded =
      if byte_size(literal) == hd(lengths) do
        literal
        |> String.graphemes()
        |> Enum.map_join(&(&1 <> &1))
      else
        literal
      end

    with true <- byte_size(literal) in lengths,
         {value, ""} <- Integer.parse(expanded, 16) do
      value
    else
      _other ->
        expected = Enum.join(lengths, " or ")
        invalid_literal!(name, "#{expected} hexadecimal digits", caller)
    end
  end

  defp invalid_literal!(name, expected, caller) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: "~#{name} expects #{expected} without a leading # or modifiers"
  end
end
