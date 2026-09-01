defmodule GPUI.Native.PrecompiledConfigurationTest do
  use ExUnit.Case, async: true

  @loader "apps/gpui_native/lib/gpui/native/nif.ex"
  @package "apps/gpui_native/mix.exs"
  @workflow ".github/workflows/precompiled-nif.yml"

  test "uses the RustlerPrecompiled module identity for checksums" do
    loader = File.read!(@loader)
    package = File.read!(@package)

    assert loader =~ "checksum-Elixir.GPUI.Native.NIF.exs"
    assert package =~ "checksum-Elixir.GPUI.Native.NIF.exs"
    refute loader =~ "checksum-Elixir.GPUI.Native.exs"
    refute package =~ "checksum-Elixir.GPUI.Native.exs"
  end

  test "selects coordinated release assets and both named variants" do
    loader = File.read!(@loader)

    assert loader =~ ~S[/releases/download/v#{version}]
    assert loader =~ ~s(vanilla: fn -> host == :vanilla end)
    assert loader =~ ~s("gpui-component": fn -> host == :gpui_component end)
  end

  test "build workflow provides one exact Cargo feature set per archive variant" do
    workflow = File.read!(@workflow)

    assert workflow =~ "project-dir: ."
    assert workflow =~ "--manifest-path Cargo.toml"
    assert workflow =~ "variant: ${{ matrix.host }}"
    assert workflow =~ "host: vanilla"
    assert workflow =~ "cargo_features: vanilla-host"
    assert workflow =~ "host: gpui-component"
    assert workflow =~ "cargo_features: gpui-component-host"
    assert workflow =~ "--no-default-features"

    assert workflow =~
             ~S|libgpui_nif-v${VERSION}-nif-2.15-x86_64-unknown-linux-gnu--${HOST}.so.tar.gz|

    assert workflow =~ "mix gpui.release.check.glibc"
    assert workflow =~ "--max-version 2.35"
    assert workflow =~ "checksum-Elixir.GPUI.Native.NIF.exs"
    assert workflow =~ "rustler_precompiled.download GPUI.Native.NIF --all --print"
  end

  test "defines clean no-Cargo validation for both published hosts" do
    task = File.read!("dev/mix/tasks/gpui.test.precompiled.ex")

    assert task =~ ~S|defp parse_host!("vanilla"), do: :vanilla|
    assert task =~ ~S|defp parse_host!("gpui_component"), do: :gpui_component|
    assert task =~ ~S|{"CARGO", Path.join(System.tmp_dir!(), "gpui-no-cargo")}|
    assert task =~ "GPUI.Native.host_info()"
  end
end
