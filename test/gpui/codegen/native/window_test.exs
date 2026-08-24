defmodule GPUI.Codegen.Native.WindowTest do
  use RustQ.Test, async: true

  alias GPUI.Codegen.Native.Window
  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust
  alias RustQ.Rust.AST

  test "derives the native window payload and normalization from one typed contract" do
    source = Window |> RustQ.Native.items() |> Rust.render_all()

    assert %AST.Struct{name: :Decoded} = MetaAST.type_item!(Window, :Decoded)
    assert %AST.Struct{name: :Config} = MetaAST.type_item!(Window, :Config)
    assert source =~ "#[derive(Clone, Debug, rustler::NifMap)]"
    assert source =~ ~r/fn normalize<'a>\(decoded: Decoded<'a>\) -> NifResult<Config<'a>>/
    assert source =~ "pub root: Root<'a>"
    assert source =~ "pub tree: Term<'a>"
    assert source =~ ~r/tree: decoded\s*\.root\s*\.tree/
    assert source =~ ~r/decoded\s*\.lifecycle/
    assert source =~ "chrome_content()"
    refute source =~ "fn window_tree"
    assert RustQ.valid?(source, "generated_window.rs")
  end

  test "generates typed update and close requests for the handwritten orchestration boundary" do
    source = rust_source!(Window)

    assert %AST.Struct{name: :UpdateRequest} = MetaAST.type_item!(Window, :UpdateRequest)
    assert %AST.Struct{name: :CloseRequest} = MetaAST.type_item!(Window, :CloseRequest)
    assert nif_exported?(Window, :open_window, 2)
    assert source =~ "open_window_impl(env, runtime, window)"
    assert nif_exported?(Window, :update_window, 3)
    assert nif_exported?(Window, :close_window, 2)
    assert source =~ ~r/#\[rustler::nif\(schedule = "DirtyIo"\)\]\s+.*fn update_window/s
    assert source =~ "fn update_request<'a>(window_id: u64, tree: Term<'a>) -> UpdateRequest<'a>"
    assert source =~ "fn close_request(window_id: u64) -> CloseRequest"
    assert source =~ "fn decode_close(request: CloseRequest) -> u64"
    assert source =~ "update_window_impl(env, runtime, request)"
    assert source =~ "close_window_impl(env, runtime, close_request(window_id))"
    assert nif_exported?(Window, :await_frame, 3)
    assert nif_exported?(Window, :frame_token, 2)
    assert nif_exported?(Window, :await_frame_after, 4)
    assert %AST.Struct{name: :FrameRequest} = MetaAST.type_item!(Window, :FrameRequest)
    assert %AST.Struct{name: :FrameAfterRequest} = MetaAST.type_item!(Window, :FrameAfterRequest)
    assert %AST.Enum{name: :Theme} = MetaAST.type_item!(Window, :Theme)
    assert nif_exported?(Window, :set_theme, 2)
    assert source =~ "await_frame_impl(env, runtime, frame_request(window_id, timeout_ms))"
    assert source =~ "frame_token_impl(env, runtime, close_request(window_id))"
    assert source =~ "frame_after_request(window_id, generation, timeout_ms)"
    assert source =~ "set_theme_impl(env, runtime, mode)"
    assert source =~ "decode_element_node(request.tree)"
  end

  test "keeps malformed tree rejection in the generated element decoder" do
    window_source = rust_source!(Window)
    element_source = GPUI.Codegen.Native.Schema.items() |> Rust.render_all()

    assert window_source =~ "pub root: Root<'a>"
    assert window_source =~ "pub tree: Term<'a>"
    assert element_source =~ "fn decode_element_node"
    refute window_source =~ "fn decode_element_node"
    refute element_source =~ "fn window_tree"
  end
end
