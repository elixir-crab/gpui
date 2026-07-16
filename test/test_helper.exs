e2e? = System.get_env("GPUI_E2E") == "1"

Code.require_file("../support/ssl_certs.exs", __DIR__)

if e2e? do
  Code.require_file("support/e2e/desktop.ex", __DIR__)
end

ExUnit.start(exclude: if(e2e?, do: [], else: [:e2e]))
