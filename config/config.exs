import Config

config :gpui_native, build_native: true

cond do
  config_env() == :e2e ->
    config :gpui_native, GPUI.Native, host: :gpui_component

  config_env() == :test and config_target() == :native_test ->
    config :gpui_native, GPUI.Native, host: :gpui_component

  config_env() == :test ->
    config :gpui_native, GPUI.Native, host: :vanilla

  System.get_env("ZED_HEADLESS") == "1" ->
    config :gpui_native, GPUI.Native, host: :vanilla

  true ->
    config :gpui_native, GPUI.Native, host: :gpui_component
end
