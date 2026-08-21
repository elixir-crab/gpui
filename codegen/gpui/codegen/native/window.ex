defmodule GPUI.Codegen.Native.Window do
  @moduledoc "Defines the schema-owned native window payload and directional Rust codec."

  use RustQ.Native,
    build: false,
    load: false,
    rust_sources: ["native/gpui/src/window_codec.rs"]

  alias RustQ.Type, as: R

  @type chrome :: :system | :content
  @type lifecycle :: :close_request | :focus | :blur

  @type decoded :: %{
          required(:id) => R.u64(),
          required(:title) => String.t(),
          required(:size) => [R.u32()],
          required(:min_size) => R.option([R.u32()]),
          required(:resizable) => boolean(),
          required(:chrome) => chrome(),
          required(:lifecycle) => [R.path(:Lifecycle)],
          required(:commands) => [{String.t(), String.t()}]
        }

  @type config :: %{
          required(:id) => R.u64(),
          required(:title) => String.t(),
          required(:width) => R.f32(),
          required(:height) => R.f32(),
          required(:min_width) => R.option(R.f32()),
          required(:min_height) => R.option(R.f32()),
          required(:resizable) => boolean(),
          required(:content_chrome) => boolean(),
          required(:close_request) => boolean(),
          required(:focus) => boolean(),
          required(:blur) => boolean(),
          required(:commands) => [{String.t(), String.t()}]
        }

  @allow :dead_code
  @spec normalize(decoded()) :: R.nif_result(config())
  defrust normalize(decoded) do
    case decoded.size do
      [width, height] when deref(width) > 0 and deref(height) > 0 ->
        {min_width, min_height} = normalize_min_size(decoded.min_size)

        close_request =
          Enum.any?(decoded.lifecycle.clone(), fn event -> event == lifecycle_close_request() end)

        focus =
          Enum.any?(decoded.lifecycle.clone(), fn event -> event == lifecycle_focus() end)

        blur = Enum.any?(decoded.lifecycle, fn event -> event == lifecycle_blur() end)

        {:ok,
         %{
           id: decoded.id,
           title: decoded.title,
           width: cast(deref(width), R.f32()),
           height: cast(deref(height), R.f32()),
           min_width: min_width,
           min_height: min_height,
           resizable: decoded.resizable,
           content_chrome: decoded.chrome == chrome_content(),
           close_request: close_request,
           focus: focus,
           blur: blur,
           commands: decoded.commands
         }}

      _other ->
        {:error, badarg()}
    end
  end

  @allow :dead_code
  @spec normalize_min_size(R.option([R.u32()])) ::
          {R.option(R.f32()), R.option(R.f32())}
  defrustp(normalize_min_size(nil), do: {nil, nil})

  defrustp normalize_min_size({:some, size}) do
    case size do
      [width, height] when deref(width) > 0 and deref(height) > 0 ->
        {some(cast(deref(width), R.f32())), some(cast(deref(height), R.f32()))}

      _invalid ->
        {nil, nil}
    end
  end
end
