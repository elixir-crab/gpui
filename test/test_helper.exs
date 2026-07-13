System.put_env("ZED_HEADLESS", "1")

Code.require_file("../support/ssl_certs.exs", __DIR__)
Code.require_file("../support/test_display.ex", __DIR__)

ExUnit.start()
