defmodule GPUI.Codegen.Native.Event.Payloads do
  @moduledoc "Defines bounds and transfer event wire payloads without owning platform state."

  use RustQ.Meta

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Type, as: R

  @type element_bounds_geometry :: %{
          required(:id) => String.t(),
          required(:x) => R.f64(),
          required(:y) => R.f64(),
          required(:width) => R.f64(),
          required(:height) => R.f64(),
          required(:coordinate_space) => String.t()
        }

  @type key_stroke :: %{
          required(:key) => String.t(),
          required(:control) => boolean(),
          required(:alt) => boolean(),
          required(:shift) => boolean(),
          required(:platform) => boolean(),
          required(:repeat) => boolean()
        }

  @type terminal_size :: %{
          required(:columns) => R.u64(),
          required(:rows) => R.u64(),
          required(:cell_width) => R.f64(),
          required(:cell_height) => R.f64()
        }

  @type transfer_payload :: %{
          required(:text) => R.option(String.t()),
          required(:external_paths) => R.vec(String.t())
        }

  @type transfer_event_value :: %{
          required(:session_id) => R.u64(),
          required(:target_id) => String.t(),
          required(:x) => R.f64(),
          required(:y) => R.f64(),
          required(:coordinate_space) => String.t(),
          required(:payload) => R.option(TransferPayload.t())
        }

  @spec items() :: [RustQ.Rust.AST.item()]
  def items do
    MetaAST.struct_type_items(
      __MODULE__,
      [
        :element_bounds_geometry,
        :key_stroke,
        :terminal_size,
        :transfer_payload,
        :transfer_event_value
      ],
      derive: [:Clone, :Debug, :PartialEq, :"rustler::NifMap"],
      vis: :crate,
      field_vis: :crate,
      attrs: []
    )
    |> Enum.map(fn
      %{name: :ElementBoundsGeometry} = item ->
        %{item | attrs: [A.attr(:cfg, feature: "real-gpui")]}

      %{name: name} = item when name in [:KeyStroke, :TerminalSize] ->
        %{item | attrs: [A.attr(:cfg, feature: "real-gpui")]}

      item ->
        %{item | attrs: [A.attr(:cfg_attr, not: [feature: "components"], allow: [:dead_code])]}
    end)
  end
end
