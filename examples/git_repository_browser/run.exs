# Run from the GPUI repository with:
#   RUST_FONTCONFIG_DLOPEN=1 mix run examples/git_repository_browser/run.exs -- path/to/repository

Code.require_file("support/git_repository_browser.exs", __DIR__)

path =
  case System.argv() do
    [path | _arguments] -> Path.expand(path)
    [] -> File.cwd!()
  end

{:ok, runtime} =
  GPUI.Runtime.start_link(
    app: Examples.GitRepositoryBrowser.App,
    args: %{path: path}
  )

{:ok, _supervisor} =
  Examples.GitRepositoryBrowser.Supervisor.start_link(runtime: runtime, path: path)

IO.puts("Git Repository Browser is inspecting #{path}. Press Ctrl+C twice to exit.")
Process.sleep(:infinity)
