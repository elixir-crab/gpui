defmodule GPUI.Native.Target do
  @moduledoc false

  @spec precompiled?(String.t()) :: boolean()
  def precompiled?(architecture) when is_binary(architecture) do
    cond do
      String.contains?(architecture, "linux") ->
        String.starts_with?(architecture, "x86_64-") and
          String.ends_with?(architecture, "-linux-gnu") and
          not String.contains?(architecture, "musl")

      String.contains?(architecture, "apple-darwin") ->
        String.starts_with?(architecture, "aarch64-")

      String.contains?(architecture, "windows") ->
        String.starts_with?(architecture, "x86_64-")

      true ->
        false
    end
  end
end
