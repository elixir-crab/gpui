defmodule GPUIRuntimeTest do
  use ExUnit.Case, async: false

  @host Path.expand("../native/gpui_host/target/release/gpui_host", __DIR__)

  defmodule HelloView do
    use GPUI.View

    @impl GPUI.View
    def render(assigns) do
      ~GPUI"""
      <div class="flex flex-col items-center bg-neutral-700">
        <text>Hello {assigns.name}</text>
      </div>
      """
    end
  end

  defmodule DemoApp do
    use GPUI.Application

    @impl GPUI.Application
    def mount(_args) do
      {:ok, %{},
       [
         window "GPUI + Elixir" do
           size(500, 500)
           root(HelloView, name: "OTP")
         end
       ]}
    end
  end

  test "runtime keeps declarative windows in data backend" do
    {:ok, pid} = GPUI.Runtime.start_link(app: DemoApp, backend: :data)

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir", size: {500, 500}}] =
             GPUI.Runtime.windows(pid)

    GenServer.stop(pid)
  end

  test "runtime encodes rendered root trees for native payloads" do
    {:ok, pid} = GPUI.Runtime.start_link(app: DemoApp, backend: :data)

    payload =
      pid
      |> GPUI.Runtime.windows()
      |> hd()
      |> GPUI.Runtime.window_payload()

    assert %{
             root: %{
               module: module,
               assigns: %{name: "OTP"},
               tree: %{
                 type: :div,
                 attrs: %{
                   style: [
                     display: :flex,
                     flex_direction: :column,
                     align_items: :center,
                     background: [:rgb, 4_210_752]
                   ]
                 },
                 children: [%{type: :text, children: ["Hello ", "OTP"]}]
               }
             }
           } = payload

    assert module =~ "HelloView"

    GenServer.stop(pid)
  end

  test "runtime sends declared windows to native Rustler backend" do
    {:ok, pid} = GPUI.Runtime.start_link(app: DemoApp, backend: :native)

    assert [%GPUI.WindowSpec{title: "GPUI + Elixir", size: {500, 500}}] =
             GPUI.Runtime.windows(pid)

    assert_receive_host_message(pid, %{
      op: :native_event,
      payload: "window_open_requested:GPUI + Elixir"
    })

    GenServer.stop(pid)
  end

  test "runtime sends declared windows to host backend" do
    unless File.exists?(@host) do
      Mix.shell().info("Skipping runtime host test; run mix gpui.host.build first")
    else
      {:ok, pid} = GPUI.Runtime.start_link(app: DemoApp, backend: :host, executable: @host)

      assert [%GPUI.WindowSpec{title: "GPUI + Elixir", size: {500, 500}}] =
               GPUI.Runtime.windows(pid)

      assert_receive_host_message(pid, %{
        op: :reply,
        status: :ok,
        payload: %{event: :window_open_requested}
      })

      GenServer.stop(pid)
    end
  end

  defp assert_receive_host_message(pid, expected) do
    deadline = System.monotonic_time(:millisecond) + 1_000
    assert_receive_host_message(pid, expected, deadline)
  end

  defp assert_receive_host_message(pid, expected, deadline) do
    messages = GPUI.Runtime.host_messages(pid)

    if Enum.any?(messages, &match_map?(expected, &1)) do
      assert true
    else
      if System.monotonic_time(:millisecond) > deadline do
        flunk("expected host message #{inspect(expected)}, got #{inspect(messages)}")
      else
        Process.sleep(10)
        assert_receive_host_message(pid, expected, deadline)
      end
    end
  end

  defp match_map?(expected, actual) when is_map(expected) and is_map(actual) do
    Enum.all?(expected, fn {key, value} -> match_value?(value, Map.get(actual, key)) end)
  end

  defp match_map?(_expected, _actual), do: false

  defp match_value?(expected, actual) when is_map(expected) and is_map(actual),
    do: match_map?(expected, actual)

  defp match_value?(expected, actual), do: expected == actual
end
