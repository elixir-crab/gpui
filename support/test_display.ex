defmodule GPUITest.Display do
  @moduledoc false

  use Agent

  @behaviour GPUI.Display

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
      if state.owner, do: send(state.owner, {:display_snapshot, snapshot})
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
  def inject_event(display, event) do
    Agent.update(display, &%{&1 | events: [event | &1.events]})
    {:ok, :ok}
  end
end
