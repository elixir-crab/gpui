System.put_env("ZED_HEADLESS", "1")

Code.require_file("../support/ssl_certs.exs", __DIR__)

ExUnit.start()
