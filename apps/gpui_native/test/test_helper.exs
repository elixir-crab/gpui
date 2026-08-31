project_root = Mix.Project.project_file() |> Path.dirname()
Code.require_file(GPUI.Dev.Paths.support("ssl_certs.exs"))
Code.require_file(Path.join(project_root, "test/support/examples.ex"))

if Mix.env() == :e2e do
  Code.require_file(Path.join(project_root, "test/support/desktop/window.ex"))
  Code.require_file(Path.join(project_root, "test/support/desktop/linux.ex"))
  Code.require_file(Path.join(project_root, "test/support/desktop/macos.ex"))
  Code.require_file(Path.join(project_root, "test/support/desktop/desktop.ex"))
end

ExUnit.start(exclude: [:e2e])
