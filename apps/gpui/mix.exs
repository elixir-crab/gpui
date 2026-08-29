defmodule GPUI.MixProject do
  use Mix.Project

  @version "0.2.0-dev"
  @source_url "https://github.com/dannote/gpui"

  def project do
    [
      app: :gpui,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description:
        "Renderer-independent application, session, snapshot, and declarative UI contracts for GPUI.",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger, :ssl]]
  end

  defp package do
    [
      name: "gpui",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib native guides examples mix.exs README.md CHANGELOG.md LICENSE),
      exclude_patterns: [~r{^native/target(?:/|$)}]
    ]
  end

  defp deps do
    [
      {:file_system, "~> 1.0"},
      {:phoenix_live_view, "~> 1.2.6"},
      {:safe_rpc, "~> 0.1.14"},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      filter_modules: &documented_module?/2,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/documentation.md",
        "guides/getting-started/first-application.md",
        "guides/concepts/sessions-snapshots-and-displays.md",
        "guides/ui/components.md",
        "guides/ui/templates-and-elements.md",
        "guides/ui/forms-and-controls.md",
        "guides/ui/collections-and-data-views.md",
        "guides/ui/text-and-editing.md",
        "guides/ui/editable-text.md",
        "guides/ui/layout-styling-and-presentation.md",
        "guides/ui/presentation-primitives.md",
        "guides/ui/resources-and-display-actions.md",
        "guides/ui/windows-and-lifecycle.md",
        "guides/ui/commands-and-shortcuts.md",
        "guides/ui/overlays-and-menus.md",
        "guides/remote/remote-displays.md",
        "guides/testing/overview.md",
        "guides/testing/application-tests.md",
        "guides/testing/native-tests.md",
        "guides/testing/desktop-e2e.md",
        "guides/testing/coverage-ownership.md",
        "guides/deployment/native-builds.md",
        "guides/internals/platform-support.md",
        "guides/internals/editable-text-internals.md",
        "guides/internals/accessibility.md",
        "guides/internals/text-projections.md",
        "guides/internals/transfers.md",
        "guides/internals/presentation-contracts.md",
        "guides/internals/decisions/declarative-motion.md",
        "guides/internals/decisions/window-chrome.md"
      ],
      groups_for_extras: [
        Introduction: ["README.md", "guides/documentation.md"],
        "Getting Started": ~r/guides\/getting-started\//,
        Concepts: ~r/guides\/concepts\//,
        UI: ~r/guides\/ui\//,
        Remote: ~r/guides\/remote\//,
        Testing: ~r/guides\/testing\//,
        Deployment: ~r/guides\/deployment\//,
        Internals: ~r/guides\/internals\//
      ],
      groups_for_modules: [
        Core: [
          GPUI,
          GPUI.Application,
          GPUI.Command,
          GPUI.Snapshot,
          GPUI.Runtime,
          GPUI.Runtime.Update,
          GPUI.View
        ],
        "Advanced infrastructure": [GPUI.Session],
        Text: [
          GPUI.Text.Buffer,
          GPUI.Text.Position,
          GPUI.Text.Range,
          GPUI.Text.Edit,
          GPUI.Text.Selection,
          GPUI.Text.Transaction,
          GPUI.Text.Snapshot,
          GPUI.Text.Viewport,
          GPUI.Text.CaretGeometry,
          GPUI.Text.RangeGeometry,
          GPUI.Text.Rectangle,
          GPUI.Text.Decoration,
          GPUI.Text.InlineProjection,
          GPUI.Text.BlockProjection
        ],
        Displays: [GPUI.Display, GPUI.Display.Native],
        Elements: [
          GPUI.UI,
          GPUI.UI.Overlay,
          GPUI.Element,
          GPUI.Event,
          GPUI.Image,
          GPUI.Raster,
          GPUI.ResourceRef,
          GPUI.Schema.Extension,
          GPUI.Schema.Extension.Support,
          GPUI.Tailwind,
          GPUI.Template,
          GPUI.WindowSpec
        ],
        Remote: [
          GPUI.Remote.Server,
          GPUI.Remote.Client,
          GPUI.Remote.Protocol,
          GPUI.Remote.Transport.TCP
        ],
        Testing: [GPUI.Test, GPUI.Test.UI, GPUI.Test.Display]
      ]
    ]
  end

  defp documented_module?(module, _metadata) do
    module in documented_modules()
  end

  defp documented_modules do
    [
      GPUI,
      GPUI.Accessibility,
      GPUI.Native,
      GPUI.Application,
      GPUI.Schema.Component,
      GPUI.Schema.Extension,
      GPUI.Schema.Extension.Support,
      GPUI.Command,
      GPUI.Session,
      GPUI.Snapshot,
      GPUI.Runtime,
      GPUI.Runtime.Update,
      GPUI.View,
      GPUI.Text.Buffer,
      GPUI.Text.Position,
      GPUI.Text.Range,
      GPUI.Text.Edit,
      GPUI.Text.Selection,
      GPUI.Text.Transaction,
      GPUI.Text.Snapshot,
      GPUI.Text.Viewport,
      GPUI.Text.CaretGeometry,
      GPUI.Text.RangeGeometry,
      GPUI.Text.Rectangle,
      GPUI.Text.Decoration,
      GPUI.Text.InlineProjection,
      GPUI.Text.BlockProjection,
      GPUI.Text.StyleRun,
      GPUI.Text.RichRun,
      GPUI.Transfer.Payload,
      GPUI.Transfer.Event,
      GPUI.Display,
      GPUI.Display.Native,
      GPUI.UI,
      GPUI.UI.Overlay,
      GPUI.Element,
      GPUI.Event,
      GPUI.Image,
      GPUI.Raster,
      GPUI.ResourceRef,
      GPUI.Tailwind,
      GPUI.Template,
      GPUI.WindowSpec,
      GPUI.Remote.Server,
      GPUI.Remote.Client,
      GPUI.Remote.Protocol,
      GPUI.Remote.Transport.TCP,
      GPUI.Test,
      GPUI.Test.UI,
      GPUI.Test.Display,
      Mix.Tasks.Gpui.Release.Check
    ]
  end
end
