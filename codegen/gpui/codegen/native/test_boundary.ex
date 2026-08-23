defmodule GPUI.Codegen.Native.TestBoundary do
  @moduledoc "Defines RustQ-owned deterministic native-test lifecycle NIF boundaries."

  use RustQ.Native,
    build: false,
    load: false,
    rust_sources: ["native/gpui/src/nif.rs"]

  alias RustQ.Type, as: R

  @type point_request :: %{
          required(:x) => R.f64(),
          required(:y) => R.f64()
        }

  @type scroll_request :: %{
          required(:target) => String.t(),
          required(:delta_x) => R.f64(),
          required(:delta_y) => R.f64()
        }

  @type render_request :: %{
          required(:tree) => term()
        }

  @type resize_request :: %{
          required(:width) => R.f64(),
          required(:height) => R.f64()
        }

  @type target_request :: %{
          required(:target) => String.t()
        }

  @spec point_request(R.f64(), R.f64()) :: point_request()
  defrust point_request(x, y), do: %{x: x, y: y}

  @spec scroll_request(String.t(), R.f64(), R.f64()) :: scroll_request()
  defrust scroll_request(target, delta_x, delta_y),
    do: %{target: target, delta_x: delta_x, delta_y: delta_y}

  @spec render_request(term()) :: render_request()
  defrust render_request(tree), do: %{tree: tree}

  @spec resize_request(R.f64(), R.f64()) :: resize_request()
  defrust resize_request(width, height), do: %{width: width, height: height}

  @spec target_request(String.t()) :: target_request()
  defrust target_request(target), do: %{target: target}

  @nif schedule: :dirty_io
  @spec native_test_start(R.f64(), R.f64()) :: R.nif_result(term())
  defnif native_test_start(width, height), do: native_test_start_impl(nif_env(), width, height)

  @nif schedule: :dirty_io
  @spec native_test_render(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          term()
        ) :: R.nif_result(term())
  defnif native_test_render(session, tree) do
    native_test_render_impl(nif_env(), session, render_request(tree))
  end

  @nif schedule: :dirty_io
  @spec native_test_resize(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.f64(),
          R.f64()
        ) :: R.nif_result(term())
  defnif native_test_resize(session, width, height) do
    native_test_resize_impl(nif_env(), session, resize_request(width, height))
  end

  @nif schedule: :dirty_io
  @spec native_test_bounds(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          String.t()
        ) :: R.nif_result(term())
  defnif native_test_bounds(session, target) do
    native_test_bounds_impl(nif_env(), session, target_request(target))
  end

  @nif schedule: :dirty_io
  @spec native_test_focus(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          String.t()
        ) :: R.nif_result(term())
  defnif native_test_focus(session, target) do
    native_test_focus_impl(nif_env(), session, target_request(target))
  end

  @nif schedule: :dirty_io
  @spec native_test_click(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          String.t()
        ) :: R.nif_result(term())
  defnif native_test_click(session, target) do
    native_test_click_impl(nif_env(), session, target_request(target))
  end

  @nif schedule: :dirty_io
  @spec native_test_click_at(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          R.f64(),
          R.f64()
        ) :: R.nif_result(term())
  defnif native_test_click_at(session, x, y) do
    native_test_click_at_impl(nif_env(), session, point_request(x, y))
  end

  @nif schedule: :dirty_io
  @spec native_test_scroll(
          R.raw(:"ResourceArc<native_test::NativeTestSessionResource>"),
          String.t(),
          R.f64(),
          R.f64()
        ) :: R.nif_result(term())
  defnif native_test_scroll(session, target, delta_x, delta_y) do
    native_test_scroll_impl(nif_env(), session, scroll_request(target, delta_x, delta_y))
  end

  @nif schedule: :dirty_io
  @spec native_test_idle(R.raw(:"ResourceArc<native_test::NativeTestSessionResource>")) ::
          R.nif_result(term())
  defnif native_test_idle(session), do: native_test_idle_impl(nif_env(), session)

  @nif schedule: :dirty_io
  @spec native_test_events(R.raw(:"ResourceArc<native_test::NativeTestSessionResource>")) ::
          R.nif_result(term())
  defnif native_test_events(session), do: native_test_events_impl(nif_env(), session)

  @nif schedule: :dirty_io
  @spec native_test_stop(R.raw(:"ResourceArc<native_test::NativeTestSessionResource>")) ::
          R.nif_result(term())
  defnif native_test_stop(session), do: native_test_stop_impl(nif_env(), session)
end
