Code.require_file(
  "../../../examples/git_repository_browser/support/git_repository_browser.exs",
  __DIR__
)

defmodule GPUITest.Visual.GitRepositoryBrowser.Scenario do
  @behaviour GPUI.Dev.Visual.Scenario

  @impl GPUI.Dev.Visual.Scenario
  def id, do: :git_repository_browser

  @impl GPUI.Dev.Visual.Scenario
  def app, do: Examples.GitRepositoryBrowser.App

  @impl GPUI.Dev.Visual.Scenario
  def args(_theme) do
    repository = repository()

    %{
      path: repository.root,
      repository: repository,
      selected_path: "lib/gpui/runtime.ex",
      preview: runtime_preview(),
      expanded: expanded()
    }
  end

  @impl GPUI.Dev.Visual.Scenario
  def title, do: "Git Repository Browser"

  @impl GPUI.Dev.Visual.Scenario
  def captures do
    [
      %{name: "repository"},
      %{
        name: "filtered-untracked",
        actions: [
          {:dispatch,
           %{type: :change, window_id: 1, event: "status_filter_changed", value: "untracked"}},
          {:send_view_from, 1,
           fn assigns ->
             {:tree_slice, assigns.tree_generation,
              Examples.GitRepositoryBrowser.Model.tree_slice(
                repository(),
                expanded(),
                "",
                "untracked",
                Examples.GitRepositoryBrowser.Model.initial_range(),
                "lib/gpui/runtime.ex"
              )}
           end}
        ]
      },
      %{
        name: "selected-readme",
        actions: [
          {:dispatch,
           %{type: :change, window_id: 1, event: "status_filter_changed", value: "all"}},
          {:send_view_from, 1,
           fn assigns ->
             {:tree_slice, assigns.tree_generation,
              Examples.GitRepositoryBrowser.Model.tree_slice(
                repository(),
                expanded(),
                "",
                "all",
                Examples.GitRepositoryBrowser.Model.initial_range(),
                "lib/gpui/runtime.ex"
              )}
           end},
          {:dispatch,
           %{type: :change, window_id: 1, event: "tree_selected", value: "file:README.md"}},
          {:send_view_from, 1,
           fn assigns ->
             {:tree_slice, assigns.tree_generation,
              Examples.GitRepositoryBrowser.Model.tree_slice(
                repository(),
                expanded(),
                "",
                "all",
                Examples.GitRepositoryBrowser.Model.initial_range(),
                "README.md"
              )}
           end},
          {:send_view_from, 1,
           fn assigns ->
             {:preview_loaded, assigns.preview_job, assigns.preview_generation,
              Examples.GitRepositoryBrowser.Model.preview_summary(readme_preview()),
              Examples.GitRepositoryBrowser.Model.preview_slice(
                readme_preview(),
                Examples.GitRepositoryBrowser.Model.initial_range()
              )}
           end}
        ]
      }
    ]
  end

  defp expanded do
    MapSet.new([
      ".github",
      ".github/workflows",
      "examples",
      "examples/git_repository_browser",
      "lib",
      "lib/gpui",
      "native",
      "test"
    ])
  end

  defp repository do
    files = [
      file(".github/workflows/ci.yml", :modified),
      file(".github/workflows/native.yml", :clean),
      file("CHANGELOG.md", :clean),
      file("README.md", :modified),
      file("examples/git_repository_browser/run.exs", :untracked),
      file("lib/gpui.ex", :clean),
      file("lib/gpui/display.ex", :clean),
      file("lib/gpui/runtime.ex", :modified),
      file("lib/gpui/session.ex", :clean),
      file("lib/gpui/ui.ex", :modified),
      file("mix.exs", :clean),
      file("native/gpui/Cargo.toml", :clean),
      file("native/gpui/src/lib.rs", :clean),
      file("native/gpui/src/runtime.rs", :modified),
      file("test/gpui/runtime_test.exs", :clean),
      file("test/gpui/ui_test.exs", :clean)
    ]

    %{
      root: "/workspace/gpui",
      name: "gpui",
      branch: "main",
      files: files,
      counts: %{total: length(files), clean: 10, changed: 6}
    }
  end

  defp file(path, status), do: %{path: path, name: Path.basename(path), status: status}

  defp runtime_preview do
    lines(
      [
        {"diff --git a/lib/gpui/runtime.ex b/lib/gpui/runtime.ex", :header},
        {"--- a/lib/gpui/runtime.ex", :header},
        {"+++ b/lib/gpui/runtime.ex", :header},
        {"@@ -142,6 +142,12 @@ defmodule GPUI.Runtime do", :hunk},
        {"   def snapshot(runtime), do: GenServer.call(runtime, :snapshot)", :context},
        {"+", :added},
        {"+  def request_frame(runtime) do", :added},
        {"+    GenServer.call(runtime, :request_frame)", :added},
        {"+  end", :added},
        {" ", :context},
        {"   def dispatch_event(runtime, event) do", :context},
        {"-    GenServer.call(runtime, {:event, event})", :deleted},
        {"+    GenServer.call(runtime, {:dispatch_event, event})", :added},
        {"   end", :context}
      ],
      "lib/gpui/runtime.ex",
      :modified,
      :diff
    )
  end

  defp readme_preview do
    lines(
      [
        {"diff --git a/README.md b/README.md", :header},
        {"--- a/README.md", :header},
        {"+++ b/README.md", :header},
        {"@@ -24,6 +24,9 @@ Build native desktop interfaces from Elixir.", :hunk},
        {" ", :context},
        {"+Browse large repositories with virtualized trees and diffs.", :added},
        {"+Filesystem work remains supervised and bounded.", :added},
        {"+", :added},
        {" See the examples directory for complete applications.", :context}
      ],
      "README.md",
      :modified,
      :diff
    )
  end

  defp lines(rows, path, status, mode) do
    lines =
      rows
      |> List.duplicate(8)
      |> List.flatten()
      |> Enum.with_index(1)
      |> Enum.map(fn {{text, kind}, number} ->
        %{id: "line-#{number}", number: number, text: text, kind: kind}
      end)

    %{path: path, status: status, mode: mode, lines: lines}
  end
end
