defmodule GPUI.CommandSpec do
  @moduledoc """
  Source of truth for the RustQ-generated GPUI host protocol.

  The first implementation slice keeps this intentionally small. Later phases
  will generate Rust command enums/decoders, Port protocol code, and Rustler
  NIF wrappers from these specs.
  """

  @spec commands() :: keyword()
  def commands do
    [
      open_window: [args: [title: :string, size: {:tuple, [:integer, :integer]}, root: :root]],
      close_window: [args: [window_id: :integer]],
      update_view: [args: [view_id: :integer, tree: :element_tree]]
    ]
  end

  @spec host_commands() :: keyword()
  def host_commands do
    [ping: [args: []], shutdown: [args: []]] ++ commands()
  end
end
