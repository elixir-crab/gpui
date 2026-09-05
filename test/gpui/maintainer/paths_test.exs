defmodule GPUI.Maintainer.PathsTest do
  use ExUnit.Case, async: true

  alias GPUI.Maintainer.Paths

  test "discovers the repository root from stable workspace markers" do
    root = Paths.root()

    assert File.regular?(Path.join(root, "mix.exs"))
    assert File.regular?(Path.join(root, "Cargo.toml"))
    assert File.dir?(Path.join(root, "apps"))
    assert File.dir?(Path.join(root, "codegen"))
  end

  test "builds named repository paths without caller-side traversal" do
    assert Paths.app(:gpui) == Path.join(Paths.root(), "apps/gpui")
    assert Paths.support("ssl_certs.exs") == Path.join(Paths.root(), "support/ssl_certs.exs")

    assert Paths.codegen_native() ==
             Path.join(Paths.root(), "codegen/gpui/codegen/native")
  end
end
