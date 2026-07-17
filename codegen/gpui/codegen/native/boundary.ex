defmodule GPUI.Codegen.Native.Boundary do
  @moduledoc false

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.Identifier
  alias RustQ.Syn.Type

  @real_only_nifs [
    :open_window,
    :update_window,
    :close_window,
    :await_frame,
    :frame_token,
    :await_frame_after,
    :set_theme,
    :put_resource,
    :drop_resource
  ]

  @spec nifs() :: keyword(keyword())
  def nifs do
    [
      start_runtime: [],
      open_window: [schedule: :dirty_cpu],
      update_window: [schedule: :dirty_cpu],
      close_window: [schedule: :dirty_cpu],
      await_frame: [schedule: :dirty_cpu],
      frame_token: [schedule: :dirty_cpu],
      await_frame_after: [schedule: :dirty_cpu],
      stop_runtime: [schedule: :dirty_cpu],
      set_theme: [schedule: :dirty_cpu],
      put_resource: [schedule: :dirty_cpu],
      drop_resource: [],
      drain_events: [],
      inject_event: []
    ]
  end

  @spec disabled_items() :: [AST.item()]
  def disabled_items do
    functions =
      "native/gpui/src/nif.rs"
      |> RustQ.Syn.parse_file!()
      |> RustQ.Syn.functions()

    Enum.map(@real_only_nifs, fn name ->
      source_name = "#{name}_impl"
      function = Enum.find(functions, &(&1.name == source_name)) || missing_function!(source_name)

      %AST.Function{
        name: name |> Atom.to_string() |> Kernel.<>("_impl") |> String.to_atom(),
        vis: :crate,
        lifetimes: Enum.map(function.lifetimes, &lifetime/1),
        args:
          Enum.map(function.args, fn arg ->
            A.arg(String.to_atom("_#{arg.name}"), type_ast(arg.type_ast))
          end),
        returns: type_ast(function.returns_ast),
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

  defp type_ast(%Type.Path{} = path) do
    generic_args =
      if path.generic_args == [] do
        Enum.map(path.args, &%Type.GenericArgument{kind: :type, type: &1})
      else
        path.generic_args
      end

    %AST.TypePath{
      parts: Enum.map(path.segments, &Identifier.atom!/1),
      lifetimes:
        for(
          %Type.GenericArgument{kind: :lifetime, source: source} <- generic_args,
          do: lifetime(source)
        ),
      generics:
        for(
          %Type.GenericArgument{kind: :type, type: type} <- generic_args,
          do: type_ast(type)
        )
    }
  end

  defp lifetime("'" <> name), do: Identifier.atom!(name)
  defp lifetime(name), do: Identifier.atom!(name)

  defp missing_function!(name),
    do: raise(ArgumentError, "missing native NIF implementation #{name}")
end
