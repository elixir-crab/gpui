for example <- ~w(hello_window events focus_timer controlled_form multiple_windows)a do
  GPUITest.Examples.load!(example)
end

defmodule GPUI.Examples.GettingStartedTest do
  use GPUI.Test, async: true

  test "window lesson renders one declarative view" do
    runtime = start_runtime!(GettingStarted.HelloWindow.App)

    assert %{title: "Hello GPUI", size: [420, 240]} = window_snapshot(runtime)
    assert %{type: :text, children: ["Hello, GPUI"]} = runtime |> tree() |> find!(type: :text)
  end

  test "events lesson keeps counter state in Elixir" do
    runtime = start_runtime!(GettingStarted.Events.App)

    assert %{count: 0} = assigns(runtime)
    click(runtime, "increment")
    click(runtime, "increment")
    click(runtime, "decrement")
    assert %{count: 1} = assigns(runtime)
  end

  test "supervised updates lesson receives worker messages" do
    runtime = start_runtime!(GettingStarted.FocusTimer.App, args: %{seconds: 2})

    ticker =
      start_supervised!(
        {GettingStarted.FocusTimer.Ticker, runtime: runtime, interval: :timer.hours(1)}
      )

    click(runtime, "start")
    send(ticker, :tick)
    _ticker_state = :sys.get_state(ticker)
    assert %{remaining: 1, status: :running} = assigns(runtime)

    send_view(runtime, :tick)
    assert %{remaining: 0, status: :complete} = assigns(runtime)
  end

  test "controlled form owns values and validation" do
    runtime = start_runtime!(GettingStarted.ControlledForm.App)

    change(runtime, "name_changed", "")
    click(runtime, "save")
    assert %{error: "Enter a display name.", status: "Not saved"} = assigns(runtime)

    change(runtime, "name_changed", "Grace Hopper")
    change(runtime, "notifications_changed", false)
    click(runtime, "save")

    assert %{name: "Grace Hopper", notifications: false, error: nil, status: "Saved"} =
             assigns(runtime)
  end

  test "multiple-window lesson changes declarative topology" do
    runtime = start_runtime!(GettingStarted.MultipleWindows.App)

    assert [%{key: "main"}] = snapshot(runtime).windows
    click(runtime, "toggle_details")
    assert [%{key: "main"}, %{key: "details"}] = snapshot(runtime).windows
    click(runtime, "toggle_details", window_id: 1)
    assert [%{key: "main"}] = snapshot(runtime).windows
  end
end
