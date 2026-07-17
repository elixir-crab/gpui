for example <- ~w(hello_window focus_timer settings_form) do
  Code.require_file("../../examples/getting_started/support/#{example}.exs", __DIR__)
end

defmodule GPUI.GettingStartedExamplesTest do
  use GPUI.Test, async: true

  test "hello window renders a useful runtime status" do
    runtime = start_gpui!(GettingStarted.HelloWindow.App)

    assert %{title: "Hello GPUI"} = window_snapshot(runtime)
    assert %{type: :div, children: children} = tree(runtime)
    assert Enum.any?(children, &match?(%{type: :text, children: ["● Runtime connected"]}, &1))
  end

  test "focus timer handles controls and OTP ticks" do
    runtime = start_gpui!(GettingStarted.FocusTimer.App, args: %{seconds: 2})

    ticker =
      start_supervised!(
        {GettingStarted.FocusTimer.Ticker, runtime: runtime, interval: :timer.hours(1)}
      )

    assert %{remaining: 2, status: :ready} = assigns(runtime)
    click(runtime, "start")
    send(ticker, :tick)
    _ticker_state = :sys.get_state(ticker)
    assert %{remaining: 1, status: :running} = assigns(runtime)

    send_view(runtime, :tick)
    assert %{remaining: 0, status: :complete} = assigns(runtime)

    click(runtime, "start")
    assert %{remaining: 2, status: :running} = assigns(runtime)
    click(runtime, "pause")
    click(runtime, "reset")
    assert %{remaining: 2, status: :ready} = assigns(runtime)
  end

  test "settings form remains controlled and confirms changes" do
    runtime = start_gpui!(GettingStarted.SettingsForm.App)

    change(runtime, "name_changed", "Grace Hopper")
    select(runtime, "preview_changed", "paper")
    toggle(runtime, "notifications_changed", false)
    select(runtime, "density_changed", "compact")
    slide(runtime, "volume_changed", 40.0)

    assert %{
             name: "Grace Hopper",
             preview: "paper",
             notifications: false,
             density: "compact",
             volume: 40.0,
             saved: false
           } = assigns(runtime)

    click(runtime, "review")
    assert %{dialog_open: true} = assigns(runtime)
    click(runtime, "apply")
    assert %{dialog_open: false, saved: true} = assigns(runtime)
  end
end
