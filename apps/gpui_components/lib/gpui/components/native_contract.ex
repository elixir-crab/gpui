defmodule GPUI.Components.NativeContract do
  @moduledoc """
  Inspectable native contract derived from component-package schema declarations.

  This is static declaration data used by RustQ generation. It does not register
  native implementations or permit runtime extension.
  """

  alias GPUI.Components.Schema.Declarations

  @event_payloads %{
    change: :value,
    cell_change: :value,
    click: :none,
    clipboard: :transfer,
    clipboard_write: :none,
    copy: :none,
    drag_enter: :transfer,
    drag_leave: :transfer,
    drag_move: :transfer,
    drop: :transfer,
    file_read: :file_dialog,
    focus: :none,
    blur: :none,
    geometry: :text_geometry,
    hit_test: :text_position,
    keydown: :input,
    keyup: :input,
    link: :value,
    range: :value,
    release: :value,
    search: :value,
    select: :value,
    sort: :value,
    submit: :value,
    toggle: :value,
    range_geometry: :text_range_geometry,
    selection: :text_selection,
    transaction: :text_transaction,
    viewport: :text_viewport
  }

  @type event_payload ::
          :none
          | :value
          | :input
          | :transfer
          | :file_dialog
          | :text_geometry
          | :text_position
          | :text_range_geometry
          | :text_selection
          | :text_transaction
          | :text_viewport

  @type component_contract :: %{
          tag: atom(),
          kind: atom(),
          stateful?: boolean(),
          events: [%{name: atom(), attr: atom(), payload: event_payload()}]
        }

  @doc "Returns the complete conventional component-host contract."
  @spec components() :: [component_contract()]
  def components do
    Enum.map(Declarations.components(), fn component ->
      %{
        tag: component.tag,
        kind: component.kind,
        stateful?: component.stateful,
        events:
          Enum.map(component.events, fn {name, attr} ->
            %{name: name, attr: attr, payload: Map.fetch!(@event_payloads, name)}
          end)
      }
    end)
  end

  @doc "Returns unique event contracts in canonical declaration order."
  @spec events() :: [%{name: atom(), payload: event_payload()}]
  def events do
    components()
    |> Enum.flat_map(& &1.events)
    |> Enum.reduce({MapSet.new(), []}, fn event, {seen, events} ->
      if MapSet.member?(seen, event.name) do
        {seen, events}
      else
        {MapSet.put(seen, event.name), [Map.take(event, [:name, :payload]) | events]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  @doc "Returns an immutable capability map suitable for Elixir inspection."
  @spec capabilities() :: map()
  def capabilities do
    contracts = components()

    %{
      schema_version: 1,
      provider: GPUI.Components.Schema.Declarations,
      components: Enum.map(contracts, & &1.tag),
      stateful_components: contracts |> Enum.filter(& &1.stateful?) |> Enum.map(& &1.tag),
      events: events()
    }
  end
end
