defmodule GPUI.EventTest do
  use ExUnit.Case, async: true

  alias GPUI.Event

  test "requires an explicit known event type" do
    assert {:error, {:invalid_event, :type}} =
             Event.normalize(%{window_id: 1, event: "save"})

    assert {:error, {:unsupported_event_type, :mystery}} =
             Event.normalize(%{type: :mystery, window_id: 1})

    assert {:error, {:invalid_event, :type}} =
             Event.normalize(%{type: "click", window_id: 1, event: "save"})
  end

  test "requires a positive window id and bounded non-empty routed event name" do
    assert {:error, {:invalid_event, :window_id}} =
             Event.normalize(%{type: :click, event: "save"})

    assert {:error, {:invalid_event, :window_id}} =
             Event.normalize(%{type: :click, window_id: 0, event: "save"})

    assert {:error, {:invalid_event, :event}} =
             Event.normalize(%{type: :click, window_id: 1, event: ""})

    assert {:error, {:invalid_event, :event}} =
             Event.normalize(%{type: :click, window_id: 1, event: :save})

    assert {:error, {:invalid_event, :event}} =
             Event.normalize(%{type: :click, window_id: 1, event: :binary.copy("x", 513)})
  end

  test "accepts lifecycle events without application event names" do
    assert {:ok, %{type: :window_focus, window_id: 1}} =
             Event.normalize(%{type: :window_focus, window_id: 1})

    assert {:error, {:invalid_event, :event}} =
             Event.normalize(%{type: :window_focus, window_id: 1, event: "focus"})
  end

  test "validates representative event value shapes" do
    assert {:ok, %{type: :click}} =
             Event.normalize(%{type: :click, window_id: 1, event: "save"})

    assert {:error, {:invalid_event, :value}} =
             Event.normalize(%{type: :click, window_id: 1, event: "save", value: true})

    assert {:ok, %{value: false}} =
             Event.normalize(%{
               type: :change,
               window_id: 1,
               event: "enabled",
               value: false
             })

    assert {:error, {:invalid_event, :value}} =
             Event.normalize(%{type: :change, window_id: 1, event: "enabled", value: %{}})

    assert {:ok, %{value: %{first: 2, last: 5}}} =
             Event.normalize(%{
               type: :range,
               window_id: 1,
               event: "visible",
               value: %{first: 2, last: 5}
             })

    assert {:error, {:invalid_event, :value}} =
             Event.normalize(%{
               type: :range,
               window_id: 1,
               event: "visible",
               value: %{first: 5, last: 2}
             })
  end
end
