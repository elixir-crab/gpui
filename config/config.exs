import Config

config :gpui, GPUI.Native,
  features: if(System.get_env("GPUI_REAL_GPUI") in ["1", "true"], do: ["real-gpui"], else: [])
