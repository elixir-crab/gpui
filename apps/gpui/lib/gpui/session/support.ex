defmodule GPUI.Session.Support do
  @moduledoc """
  Internal session startup and snapshot-encoding support.

  `GPUI.Session` owns the supported renderer-independent state API. Remote
  supervision and snapshot construction use this documented support module,
  which is excluded from the public API reference.
  """

  alias GPUI.Snapshot
  alias GPUI.WindowSpec

  @doc "Starts a session whose application mount is completed by its supervisor."
  @spec start_link_deferred(keyword()) :: GenServer.on_start()
  def start_link_deferred(opts) do
    GenServer.start_link(GPUI.Session, {:deferred, opts})
  end

  @doc "Builds the complete serializable snapshot for session state."
  @spec snapshot([WindowSpec.t()], %{optional(String.t()) => map()}) :: Snapshot.t()
  def snapshot(windows, resources) when is_list(windows) and is_map(resources) do
    %Snapshot{windows: Enum.map(windows, &window_payload/1), resources: resources}
  end

  @doc "Converts a declarative window into its serializable representation."
  @spec window_payload(WindowSpec.t()) :: GPUI.Snapshot.Window.t()
  def window_payload(%WindowSpec{} = window) do
    %{
      id: window.id,
      key: window.key,
      title: window.title,
      size: Tuple.to_list(window.size || {800, 600}),
      min_size: encode_optional_size(window.min_size),
      resizable: window.resizable,
      chrome: window.chrome,
      lifecycle: window_lifecycle(window.root),
      commands: Enum.map(window.commands, &GPUI.Command.to_payload/1),
      root: encode_root(window.root)
    }
  end

  defp window_lifecycle(nil), do: []

  defp window_lifecycle({module, _assigns}) do
    if function_exported?(module, :handle_window_event, 3),
      do: [:close_request, :focus, :blur],
      else: []
  end

  defp encode_optional_size(nil), do: nil
  defp encode_optional_size(size), do: Tuple.to_list(size)

  defp encode_root(nil), do: nil

  defp encode_root({module, assigns}) do
    assigns = Map.new(assigns)

    %{
      module: inspect(module),
      assigns: assigns,
      tree: viewport(render_root(module, assigns))
    }
  end

  defp viewport(tree), do: %{type: :viewport, attrs: %{}, children: [tree]}

  defp render_root(module, assigns) do
    unless Code.ensure_loaded?(module) and function_exported?(module, :render, 1) do
      raise ArgumentError, "window root #{inspect(module)} must implement render/1"
    end

    module.render(assigns)
    |> GPUI.Element.to_payload()
  end
end
