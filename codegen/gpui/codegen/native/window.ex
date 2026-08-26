defmodule GPUI.Codegen.Native.Window do
  @moduledoc "Defines the schema-owned native window payload and directional Rust codec."

  use RustQ.Native,
    otp_app: :gpui_native,
    build: false,
    load: false,
    rust_sources: ["apps/gpui_native/native/gpui/src/window_codec.rs"]

  alias RustQ.Type, as: R

  @type chrome :: :system | :content
  @type lifecycle :: :close_request | :focus | :blur
  @type theme :: :light | :dark

  @type close_request :: %{
          required(:window_id) => R.u64()
        }

  @type update_request :: %{
          required(:window_id) => R.u64(),
          required(:tree) => term()
        }

  @type frame_request :: %{
          required(:window_id) => R.u64(),
          required(:timeout_ms) => R.u64()
        }

  @type frame_after_request :: %{
          required(:window_id) => R.u64(),
          required(:generation) => R.u64(),
          required(:timeout_ms) => R.u64()
        }

  @spec frame_request(R.u64(), R.u64()) :: frame_request()
  defrust(frame_request(window_id, timeout_ms),
    do: %{window_id: window_id, timeout_ms: timeout_ms}
  )

  @spec frame_after_request(R.u64(), R.u64(), R.u64()) :: frame_after_request()
  defrust(frame_after_request(window_id, generation, timeout_ms),
    do: %{window_id: window_id, generation: generation, timeout_ms: timeout_ms}
  )

  @spec update_request(R.u64(), term()) :: update_request()
  defrust(update_request(window_id, tree), do: %{window_id: window_id, tree: tree})

  @spec close_request(R.u64()) :: close_request()
  defrust(close_request(window_id), do: %{window_id: window_id})

  @spec decode_close(close_request()) :: R.u64()
  defrust(decode_close(request), do: request.window_id)

  @nif schedule: :dirty_io
  @spec open_window(
          R.resource(R.path(:RuntimeResource)),
          term()
        ) :: R.nif_result(term())
  defnif(open_window(runtime, window), do: open_window_impl(nif_env(), runtime, window))

  @nif schedule: :dirty_io
  @spec update_window(
          R.resource(R.path(:RuntimeResource)),
          R.u64(),
          term()
        ) :: R.nif_result(term())
  defnif update_window(runtime, window_id, tree) do
    request = update_request(window_id, tree)
    update_window_impl(nif_env(), runtime, request)
  end

  @nif schedule: :dirty_io
  @spec close_window(
          R.resource(R.path(:RuntimeResource)),
          R.u64()
        ) :: R.nif_result(term())
  defnif close_window(runtime, window_id) do
    close_window_impl(nif_env(), runtime, close_request(window_id))
  end

  @nif schedule: :dirty_io
  @spec await_frame(
          R.resource(R.path(:RuntimeResource)),
          R.u64(),
          R.u64()
        ) :: R.nif_result(term())
  defnif await_frame(runtime, window_id, timeout_ms) do
    await_frame_impl(nif_env(), runtime, frame_request(window_id, timeout_ms))
  end

  @nif schedule: :dirty_io
  @spec frame_token(
          R.resource(R.path(:RuntimeResource)),
          R.u64()
        ) :: R.nif_result(term())
  defnif frame_token(runtime, window_id) do
    frame_token_impl(nif_env(), runtime, close_request(window_id))
  end

  @nif schedule: :dirty_io
  @spec await_frame_after(
          R.resource(R.path(:RuntimeResource)),
          R.u64(),
          R.u64(),
          R.u64()
        ) :: R.nif_result(term())
  defnif await_frame_after(runtime, window_id, generation, timeout_ms) do
    await_frame_after_impl(
      nif_env(),
      runtime,
      frame_after_request(window_id, generation, timeout_ms)
    )
  end

  @nif schedule: :dirty_io
  @spec set_theme(
          R.resource(R.path(:RuntimeResource)),
          theme()
        ) :: R.nif_result(term())
  defnif set_theme(runtime, mode) do
    set_theme_impl(nif_env(), runtime, mode)
  end

  @type root :: %{
          required(:tree) => term()
        }

  @type decoded :: %{
          required(:id) => R.u64(),
          required(:title) => String.t(),
          required(:size) => [R.u32()],
          required(:min_size) => R.option([R.u32()]),
          required(:resizable) => boolean(),
          required(:chrome) => chrome(),
          required(:lifecycle) => [R.path(:Lifecycle)],
          required(:commands) => [{String.t(), String.t()}],
          required(:root) => root()
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
          required(:commands) => [{String.t(), String.t()}],
          required(:tree) => term()
        }

  @spec decode_update(update_request()) :: R.nif_result({R.u64(), R.path(:ElementNode)})
  defrust decode_update(request) do
    case decode_element_node(request.tree) do
      {:ok, tree} -> {:ok, {request.window_id, tree}}
      {:error, reason} -> {:error, reason}
    end
  end

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
           commands: decoded.commands,
           tree: decoded.root.tree
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
