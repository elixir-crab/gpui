defmodule GPUI.Codegen.Native.Boundary do
  @moduledoc "Defines generated Rustler NIF exports and disabled-native fallback implementations."

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rustler.Nif

  @native_test_facade [
    start: {:native_test_start, [:width, :height]},
    render: {:native_test_render, [:id, :tree]},
    focus: {:native_test_focus, [:id, :target]},
    click: {:native_test_click, [:id, :target]},
    click_at: {:native_test_click_at, [:id, :x, :y]},
    scroll: {:native_test_scroll, [:id, :target, :delta_x, :delta_y]},
    input: {:native_test_input, [:id, :text]},
    resize: {:native_test_resize, [:id, :width, :height]},
    bounds: {:native_test_bounds, [:id, :target]},
    settle: {:native_test_idle, [:id]},
    advance: {:native_test_advance, [:id, :milliseconds]},
    press: {:native_test_key, [:id, :key]},
    events: {:native_test_events, [:id]},
    stop: {:native_test_stop, [:id]}
  ]

  @spec native_test_facade() :: keyword({atom(), [atom()]})
  def native_test_facade, do: @native_test_facade

  @spec native_test_facade_source() :: String.t()
  def native_test_facade_source do
    definitions =
      Enum.map(@native_test_facade, fn {public_name, {nif_name, arg_names}} ->
        args = Enum.map(arg_names, &Macro.var(&1, nil))
        call = {{:., [], [GPUI.Native, nif_name]}, [], args}
        head = {public_name, [], args}

        quote do
          def unquote(head), do: unquote(call)
        end
      end)

    quote do
      defmodule GPUI.Native.Test do
        @moduledoc """
        Generated low-level façade for deterministic native-test NIF commands.

        `GPUI.Test` owns the public ExUnit workflow. This module keeps the
        generated boundary scoped and is intended for GPUI's supervised native
        test adapter rather than direct application use.
        """
        unquote_splicing(definitions)
      end
    end
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  @boundary_nifs [
    start_runtime: [schedule: :dirty_io],
    text_buffer_new: [schedule: :dirty_cpu],
    text_buffer_snapshot: [schedule: :dirty_cpu],
    text_buffer_transact: [schedule: :dirty_cpu],
    text_buffer_undo: [schedule: :dirty_cpu],
    text_buffer_redo: [schedule: :dirty_cpu],
    open_window: [schedule: :dirty_io, real_only: true],
    stop_runtime: [schedule: :dirty_io],
    drain_events: [],
    inject_event: [],
    native_test_start: [schedule: :dirty_io],
    native_test_render: [schedule: :dirty_io],
    native_test_focus: [schedule: :dirty_io],
    native_test_click: [schedule: :dirty_io],
    native_test_click_at: [schedule: :dirty_io],
    native_test_scroll: [schedule: :dirty_io],
    native_test_input: [schedule: :dirty_io],
    native_test_resize: [schedule: :dirty_io],
    native_test_bounds: [schedule: :dirty_io],
    native_test_idle: [schedule: :dirty_io],
    native_test_advance: [schedule: :dirty_io],
    native_test_key: [schedule: :dirty_io],
    native_test_events: [schedule: :dirty_io],
    native_test_stop: [schedule: :dirty_io]
  ]

  @rusty_nifs [decode_image: [schedule: :dirty_cpu]]

  @doc "Adds public source documentation to a generated Elixir module structurally."
  @spec document_generated_module(String.t(), String.t()) :: String.t()
  def document_generated_module(source, documentation) do
    source
    |> Code.string_to_quoted!()
    |> Macro.prewalk(fn
      {:@, metadata, [{:moduledoc, attribute_metadata, [false]}]} ->
        {:@, metadata, [{:moduledoc, attribute_metadata, [documentation]}]}

      node ->
        node
    end)
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  @spec nifs() :: keyword(keyword())
  def nifs, do: @boundary_nifs

  @spec rusty_nifs() :: keyword(keyword())
  def rusty_nifs, do: @rusty_nifs

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
