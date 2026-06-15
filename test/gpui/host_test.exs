defmodule GPUI.HostTest do
  use ExUnit.Case, async: false

  @host Path.expand("native/gpui_host/target/release/gpui_host", File.cwd!())

  setup do
    unless File.exists?(@host) do
      Mix.shell().info("Skipping host tests; run mix gpui.host.build first")
      :ok
    else
      port = GPUI.Host.start_link(executable: @host)
      on_exit(fn -> if Port.info(port), do: Port.close(port) end)
      {:ok, port: port}
    end
  end

  test "host replies to ping when built", %{port: port} do
    assert %{
             op: :reply,
             status: :ok,
             payload: %{pong: :ok}
           } = GPUI.Host.request(port, GPUI.Protocol.command(:ping))
  end

  test "host accepts valid open_window payload", %{port: port} do
    assert %{
             op: :reply,
             status: :ok,
             payload: %{event: :window_open_requested, backend: :stub}
           } =
             GPUI.Host.request(
               port,
               GPUI.Protocol.command(:open_window, %{
                 title: "GPUI + Elixir",
                 size: [500, 500],
                 root: %{module: "Demo.Hello", assigns: %{name: "OTP"}}
               })
             )
  end

  test "host rejects invalid open_window payload", %{port: port} do
    assert %{op: :reply, status: :error, reason: "missing_payload_field:title"} =
             GPUI.Host.request(port, GPUI.Protocol.command(:open_window, %{}))
  end
end
