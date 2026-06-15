defmodule GPUITest.SSLCerts do
  @moduledoc false

  def generate!(_context) do
    dir = Path.join(System.tmp_dir!(), "gpui_ssl_#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    ca_key = Path.join(dir, "ca.key")
    ca_cert = Path.join(dir, "ca.pem")
    server_key = Path.join(dir, "server.key")
    server_csr = Path.join(dir, "server.csr")
    server_cert = Path.join(dir, "server.pem")
    ext = Path.join(dir, "server.ext")

    openssl!(~w(genrsa -out #{ca_key} 2048))

    openssl!(
      ~w(req -x509 -new -nodes -key #{ca_key} -sha256 -days 1 -out #{ca_cert} -subj /CN=GPUI-Test-CA)
    )

    openssl!(~w(genrsa -out #{server_key} 2048))

    openssl!(~w(req -new -key #{server_key} -out #{server_csr} -subj /CN=localhost))

    File.write!(ext, "subjectAltName=DNS:localhost,IP:127.0.0.1\n")

    openssl!(
      ~w(x509 -req -in #{server_csr} -CA #{ca_cert} -CAkey #{ca_key} -CAcreateserial -out #{server_cert} -days 1 -sha256 -extfile #{ext})
    )

    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(dir) end)

    %{ca_cert: ca_cert, server_cert: server_cert, server_key: server_key}
  end

  defp openssl!(args) do
    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, status} ->
        raise "openssl #{Enum.join(args, " ")} failed with #{status}:\n#{output}"
    end
  end
end
