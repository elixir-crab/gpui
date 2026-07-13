[
  layers: [
    domain: [
      "GPUI",
      "GPUI.Application",
      "GPUI.Component",
      "GPUI.Element",
      "GPUI.Event",
      "GPUI.HTMLEngine",
      "GPUI.Inspect",
      "GPUI.Raster",
      "GPUI.ResourceRef",
      "GPUI.Schema",
      "GPUI.Schema.*",
      "GPUI.Snapshot",
      "GPUI.Tailwind",
      "GPUI.Template",
      "GPUI.View",
      "GPUI.WindowSpec"
    ],
    session: ["GPUI.Session"],
    display: ["GPUI.Display", "GPUI.Display.*"],
    runtime: ["GPUI.Runtime"],
    remote: ["GPUI.Remote", "GPUI.Remote.*"],
    native: ["GPUI.Native", "GPUI.Native.*"]
  ],
  deps: [
    forbidden: [
      {:domain, :session},
      {:domain, :display},
      {:domain, :runtime},
      {:domain, :remote},
      {:domain, :native},
      {:session, :display},
      {:session, :runtime},
      {:session, :remote},
      {:session, :native},
      {:display, :runtime},
      {:display, :remote},
      {:native, :session},
      {:native, :display},
      {:native, :runtime},
      {:native, :remote}
    ]
  ],
  smells: [strict: true]
]
