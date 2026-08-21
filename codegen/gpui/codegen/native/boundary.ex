defmodule GPUI.Codegen.Native.Boundary do
  @moduledoc "Defines generated Rustler NIF exports and disabled-native fallback implementations."

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rustler.Nif

  @spec nifs() :: keyword(keyword())
  def nifs do
    [
      start_runtime: [schedule: :dirty_io],
      text_buffer_new: [schedule: :dirty_cpu],
      text_buffer_snapshot: [schedule: :dirty_cpu],
      text_buffer_transact: [schedule: :dirty_cpu],
      text_buffer_undo: [schedule: :dirty_cpu],
      text_buffer_redo: [schedule: :dirty_cpu],
      decode_image: [schedule: :dirty_cpu],
      open_window: [schedule: :dirty_io, real_only: true],
      update_window: [schedule: :dirty_io, real_only: true],
      close_window: [schedule: :dirty_io, real_only: true],
      await_frame: [schedule: :dirty_io, real_only: true],
      frame_token: [schedule: :dirty_io, real_only: true],
      await_frame_after: [schedule: :dirty_io, real_only: true],
      stop_runtime: [schedule: :dirty_io],
      set_theme: [schedule: :dirty_io, real_only: true],
      put_resource: [schedule: :dirty_cpu, real_only: true],
      drop_resource: [real_only: true],
      drain_events: [],
      inject_event: [],
      native_test_start: [schedule: :dirty_io],
      native_test_render: [schedule: :dirty_io],
      native_test_focus: [schedule: :dirty_io],
      native_test_click: [schedule: :dirty_io],
      native_test_bounds: [schedule: :dirty_io],
      native_test_idle: [schedule: :dirty_io],
      native_test_key: [schedule: :dirty_io],
      native_test_events: [schedule: :dirty_io],
      native_test_stop: [schedule: :dirty_io]
    ]
  end

  @spec disabled_items() :: [AST.item()]
  def disabled_items do
    specs = Enum.filter(nifs(), fn {_name, opts} -> Keyword.get(opts, :real_only, false) end)

    "native/gpui/src/nif.rs"
    |> Nif.wrappers_from_source(specs)
    |> Enum.map(fn function ->
      args =
        Enum.map(function.args, fn arg ->
          %{arg | name: String.to_atom("_#{arg.name}")}
        end)

      %{
        function
        | name: String.to_atom("#{function.name}_impl"),
          vis: :crate,
          args: args,
          attrs: [],
          body: [A.return_stmt(disabled_error())]
      }
    end)
  end

  defp disabled_error do
    "real_gpui_disabled"
    |> A.lit()
    |> then(&A.path_call([:Box, :new], [&1]))
    |> then(&A.path_call([:rustler, :Error, :Term], [&1]))
    |> A.err()
  end
end
