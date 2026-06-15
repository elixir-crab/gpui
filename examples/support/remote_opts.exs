defmodule ExampleRemoteOpts do
  @moduledoc false

  def ssl_server_opts do
    if truthy?(System.get_env("GPUI_REMOTE_SSL")) do
      [
        certfile: fetch_env!("GPUI_REMOTE_SSL_CERTFILE"),
        keyfile: fetch_env!("GPUI_REMOTE_SSL_KEYFILE")
      ]
    else
      false
    end
  end

  def ssl_client_opts do
    if truthy?(System.get_env("GPUI_REMOTE_SSL")) do
      [
        verify: :verify_peer,
        cacertfile: fetch_env!("GPUI_REMOTE_SSL_CACERTFILE"),
        server_name_indication: System.get_env("GPUI_REMOTE_SSL_SERVER_NAME", "localhost") |> String.to_charlist()
      ]
    else
      false
    end
  end

  defp truthy?(value), do: value in ["1", "true", "TRUE", "yes", "YES", "on", "ON"]

  defp fetch_env!(name) do
    System.get_env(name) || raise "missing required environment variable #{name}"
  end
end
