defmodule GPUI.Codegen.Native.Boundary do
  @moduledoc "Defines shared metadata and generated Elixir façades for native boundaries."

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

  @doc "Builds a generated backend-delegating façade from generated NIF stubs."
  @spec native_facade_source(String.t()) :: String.t()
  def native_facade_source(source) do
    source
    |> Code.string_to_quoted!()
    |> Macro.prewalk(fn
      {:defmodule, metadata, [{:__aliases__, alias_metadata, [:GPUI, :Native, :Generated]}, body]} ->
        {:defmodule, metadata, [{:__aliases__, alias_metadata, [:GPUI, :Native, :Facade]}, body]}

      {:def, metadata, [{name, head_metadata, args}, [do: body]]} = definition
      when is_atom(name) and (is_list(args) or is_nil(args)) ->
        args = args || []

        if nif_error?(body) do
          call =
            quote do
              apply(GPUI.Native.backend(), unquote(name), unquote(args))
            end

          {:def, metadata, [{name, head_metadata, args}, [do: call]]}
        else
          definition
        end

      {:@, metadata, [{:moduledoc, attribute_metadata, [_documentation]}]} ->
        {:@, metadata,
         [
           {:moduledoc, attribute_metadata,
            ["Generated native boundary delegates used by GPUI.Native."]}
         ]}

      node ->
        node
    end)
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  defp nif_error?({{:., _, [{:__aliases__, _, [:erlang]}, :nif_error]}, _, [:nif_not_loaded]}),
    do: true

  defp nif_error?({{:., _, [:erlang, :nif_error]}, _, [:nif_not_loaded]}), do: true
  defp nif_error?(_body), do: false

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

  @spec rusty_nifs() :: keyword(keyword())
  def rusty_nifs, do: @rusty_nifs
end
