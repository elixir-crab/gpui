import Config

config :gpui, build_native: true

cond do
  config_env() == :e2e ->
    config :gpui, GPUI.Native,
      default_features: true,
      features: []

  config_env() == :test ->
    config :gpui, GPUI.Native,
      default_features: false,
      features: []

  System.get_env("ZED_HEADLESS") == "1" ->
    config :gpui, GPUI.Native,
      default_features: false,
      features: ["real-gpui"]

  true ->
    config :gpui, GPUI.Native,
      default_features: true,
      features: []
end
