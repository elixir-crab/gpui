defmodule GPUI.Test.Display do
  @moduledoc """
  Deterministic in-memory display for session and runtime tests.

  The display records synchronized snapshots and queues injected events without
  starting the native renderer. Pass `owner: self()` to receive each sync as
  `{:gpui_snapshot, snapshot}`.
  """

  use Agent

  @behaviour GPUI.Display

  @type state :: %{
          events: [map()],
          snapshots: [GPUI.Snapshot.t()],
          owner: pid() | nil
        }

  @impl GPUI.Display
  def start_link(opts) do
    state = fn -> %{events: [], snapshots: [], owner: Keyword.get(opts, :owner)} end

    case Keyword.get(opts, :name) do
      nil -> Agent.start_link(state)
      name -> Agent.start_link(state, name: name)
    end
  end

  @impl GPUI.Display
  def sync(display, snapshot) do
    Agent.update(display, fn state ->
      if state.owner, do: send(state.owner, {:gpui_snapshot, snapshot})
      %{state | snapshots: [snapshot | state.snapshots]}
    end)
  end

  @impl GPUI.Display
  def drain_events(display) do
    Agent.get_and_update(display, fn state ->
      {{:ok, Enum.reverse(state.events)}, %{state | events: []}}
    end)
  end

  @impl GPUI.Display
  def await_frame(display, window_id, _timeout) do
    if Agent.get(display, &window_present?(&1, window_id)),
      do: :ok,
      else: {:error, :window_not_found}
  end

  @impl GPUI.Display
  def inject_event(display, event) do
    Agent.update(display, &%{&1 | events: [event | &1.events]})
    {:ok, :ok}
  end

  defp window_present?(%{snapshots: [snapshot | _snapshots]}, window_id),
    do: Enum.any?(snapshot.windows, &(&1.id == window_id))

  defp window_present?(_state, _window_id), do: false

  @doc "Returns synchronized snapshots in chronological order."
  @spec snapshots(Agent.agent()) :: [GPUI.Snapshot.t()]
  def snapshots(display), do: Agent.get(display, &Enum.reverse(&1.snapshots))

  @doc "Returns the most recently synchronized snapshot."
  @spec latest_snapshot(Agent.agent()) :: GPUI.Snapshot.t() | nil
  def latest_snapshot(display), do: Agent.get(display, &List.first(&1.snapshots))
end
