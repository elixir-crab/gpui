import Config

config :gpui_native, build_native: true

cond do
  config_env() == :e2e ->
    config :gpui_native, GPUI.Native,
      profile: :standard,
      default_features: true,
      features: []

  config_env() == :test and config_target() == :native_test ->
    config :gpui_native, GPUI.Native,
      profile: :standard,
      default_features: false,
      features: ["native-test"]

  config_env() == :test ->
    config :gpui_native, GPUI.Native,
      profile: :core,
      default_features: false,
      features: []

  System.get_env("ZED_HEADLESS") == "1" ->
    config :gpui_native, GPUI.Native,
      profile: :core,
      default_features: false,
      features: ["real-gpui"]

  true ->
    config :gpui_native, GPUI.Native,
      profile: :standard,
      default_features: true,
      features: []
end
