Code.require_file("../support/ssl_certs.exs", __DIR__)
Code.require_file("support/examples.ex", __DIR__)

if Mix.env() in [:dev, :test] do
  Code.require_file("support/codegen.exs", __DIR__)
end

if Mix.env() == :e2e do
  Code.require_file("support/desktop/linux.ex", __DIR__)
  Code.require_file("support/desktop/macos.ex", __DIR__)
  Code.require_file("support/desktop/desktop.ex", __DIR__)
end

ExUnit.start(exclude: [:e2e])
