for example <- ~w(hello_window focus_timer settings_form)a do
  GPUITest.Examples.load!(example)
end

defmodule GPUI.GettingStartedExamplesTest do
  use GPUI.Test, async: true

  test "hello window renders a useful runtime status" do
    runtime = start_runtime!(GettingStarted.HelloWindow.App)

    assert %{title: "Hello GPUI"} = window_snapshot(runtime)
    assert %{type: :viewport, children: [%{type: :div, children: children}]} = tree(runtime)
    assert Enum.any?(children, &match?(%{type: :text, children: ["● Runtime connected"]}, &1))
  end

  test "focus timer handles controls and OTP ticks" do
    runtime = start_runtime!(GettingStarted.FocusTimer.App, args: %{seconds: 2})

    ticker =
      start_supervised!(
        {GettingStarted.FocusTimer.Ticker, runtime: runtime, interval: :timer.hours(1)}
      )

    assert %{remaining: 2, status: :ready} = assigns(runtime)

    assert %{type: :ui_progress, attrs: %{value: 0, max: 2}} =
             runtime |> tree() |> find!(id: "focus-progress")

    click(runtime, "start")
    send(ticker, :tick)
    _ticker_state = :sys.get_state(ticker)
    assert %{remaining: 1, status: :running} = assigns(runtime)

    send_view(runtime, :tick)
    assert %{remaining: 0, status: :complete} = assigns(runtime)

    assert %{attrs: %{value: 2, max: 2}} =
             runtime |> tree() |> find!(id: "focus-progress")

    click(runtime, "start")
    assert %{remaining: 2, status: :running} = assigns(runtime)
    click(runtime, "pause")
    click(runtime, "reset")
    assert %{remaining: 2, status: :ready} = assigns(runtime)
  end

  test "settings form validates, requests focus, and confirms changes" do
    runtime = start_runtime!(GettingStarted.SettingsForm.App)

    change(runtime, "name_changed", "")
    click(runtime, "review")

    assert %{
             dialog_open: false,
             errors: %{name: "Enter a display name."},
             validation_started: true,
             name_focus_request: 1
           } = assigns(runtime)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(&match?(%{children: ["Error: Enter a display name."]}, &1))

    submit(runtime, "review_submitted", "Grace Hopper")
    select(runtime, "preview_changed", "paper")
    toggle(runtime, "notifications_changed", false)
    select(runtime, "density_changed", "compact")
    change(runtime, "volume_changed", 40.0)

    assert %{
             name: "Grace Hopper",
             preview: "paper",
             notifications: false,
             density: "compact",
             volume: 40.0,
             saved: false
           } = assigns(runtime)

    assert %{dialog_open: true, errors: %{}} = assigns(runtime)

    assert runtime
           |> tree()
           |> all(type: :text)
           |> Enum.any?(fn %{children: children} ->
             Enum.join(children) == "Notification volume: 40%"
           end)

    click(runtime, "apply")
    assert %{dialog_open: false, saved: true} = assigns(runtime)
  end
end
