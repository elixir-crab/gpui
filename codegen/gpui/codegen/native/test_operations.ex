defmodule GPUI.Codegen.Native.TestOperations do
  @moduledoc "Encodes native test operation results without owning test execution."

  use RustQ.Meta,
    rust_sources: [
      "apps/gpui_native/native/src/native_test.rs",
      "apps/gpui_native/native/src/event.rs"
    ]

  alias RustQ.Meta.AST, as: MetaAST
  alias RustQ.Type, as: R

  defmacro encode_unit_result(env, operation) do
    quote do
      case unquote(operation) do
        {:ok, _unit} -> {:ok, {Atoms.ok(), Atoms.ok()}.encode(unquote(env))}
        {:error, reason} -> {:ok, {Atoms.error(), reason}.encode(unquote(env))}
      end
    end
  end

  @spec native_test_focus_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          TargetRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_focus_impl(env, session, request) do
    encode_unit_result(env, focus(ref(session), request.target))
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_focus_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_click_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          TargetRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_click_impl(env, session, request) do
    encode_unit_result(env, click(ref(session), request.target))
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_click_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_input_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          InputRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_input_impl(env, session, request) do
    encode_unit_result(env, input(ref(session), request.text))
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_input_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_key_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          KeyRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_key_impl(env, session, request) do
    encode_unit_result(env, key(ref(session), request.key))
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_key_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_advance_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          AdvanceRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_advance_impl(env, session, request) do
    encode_unit_result(env, advance(ref(session), request.milliseconds))
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_advance_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_drag_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          R.f64(),
          R.f64(),
          R.f64(),
          R.f64()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_drag_impl(env, session, from_x, from_y, to_x, to_y) do
    encode_unit_result(
      env,
      drag(
        ref(session),
        cast(from_x, R.f32()),
        cast(from_y, R.f32()),
        cast(to_x, R.f32()),
        cast(to_y, R.f32())
      )
    )
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_drag_impl(env, _session, _from_x, _from_y, _to_x, _to_y) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_click_at_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          PointRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_click_at_impl(env, session, request) do
    encode_unit_result(
      env,
      click_at(ref(session), cast(request.x, R.f32()), cast(request.y, R.f32()))
    )
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_click_at_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_scroll_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          ScrollRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_scroll_impl(env, session, request) do
    encode_unit_result(
      env,
      scroll(
        ref(session),
        request.target,
        cast(request.delta_x, R.f32()),
        cast(request.delta_y, R.f32())
      )
    )
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_scroll_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_resize_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          ResizeRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_resize_impl(env, session, request) do
    encode_unit_result(
      env,
      resize(ref(session), cast(request.width, R.f32()), cast(request.height, R.f32()))
    )
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_resize_impl(env, _session, _request) do
    {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  end

  @spec native_test_idle_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t())
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust(native_test_idle_impl(env, session), do: encode_unit_result(env, idle(ref(session))))
  @cfg not: [feature: "native-test"]
  defrust(native_test_idle_impl(env, _session),
    do: {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  )

  @spec native_test_stop_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t())
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust(native_test_stop_impl(env, session), do: encode_unit_result(env, stop(ref(session))))
  @cfg not: [feature: "native-test"]
  defrust(native_test_stop_impl(env, _session),
    do: {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  )

  @spec native_test_bounds_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          TargetRequest.t()
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_bounds_impl(env, session, request) do
    case bounds(ref(session), request.target) do
      {:ok, value} -> {:ok, {Atoms.ok(), value.x, value.y, value.width, value.height}.encode(env)}
      {:error, reason} -> {:ok, {Atoms.error(), reason}.encode(env)}
    end
  end

  @cfg not: [feature: "native-test"]
  defrust(native_test_bounds_impl(env, _session, _request),
    do: {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  )

  @spec native_test_start_impl(Env.t(R.lifetime(:a)), R.f64(), R.f64()) ::
          R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_start_impl(env, width, height) do
    case start(cast(width, R.f32()), cast(height, R.f32())) do
      {:ok, session} -> {:ok, {Atoms.ok(), ResourceArc.new(session)}.encode(env)}
      {:error, reason} -> {:ok, {Atoms.error(), reason}.encode(env)}
    end
  end

  @cfg not: [feature: "native-test"]
  defrust(native_test_start_impl(env, _width, _height),
    do: {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  )

  @spec native_test_render_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t()),
          RenderRequest.t(R.lifetime(:a))
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_render_impl(env, session, request) do
    tree = unwrap!(decode_element_node(request.tree))

    case render(ref(session), tree) do
      {:ok, _unit} -> {:ok, {Atoms.ok(), Atoms.ok()}.encode(env)}
      {:error, reason} -> {:error, enum_variant(Error, :term, Box.new(reason))}
    end
  end

  @cfg not: [feature: "native-test"]
  defrust native_test_render_impl(_env, _session, _request) do
    {:error, enum_variant(Error, :term, Box.new("native_test_disabled"))}
  end

  @spec native_test_events_impl(
          Env.t(R.lifetime(:a)),
          R.resource(NativeTest.NativeTestSessionResource.t())
        ) :: R.nif_result(term())
  @cfg feature: "native-test"
  defrust native_test_events_impl(env, session) do
    case events(ref(session)) do
      {:ok, pending} ->
        encoded =
          unwrap!(encode_pending_events(env, pending))

        {:ok, {Atoms.ok(), encoded}.encode(env)}

      {:error, reason} ->
        {:ok, {Atoms.error(), reason}.encode(env)}
    end
  end

  @cfg not: [feature: "native-test"]
  defrust(native_test_events_impl(env, _session),
    do: {:ok, {Atoms.error(), "native_test_disabled"}.encode(env)}
  )

  @spec encode_pending_events(Env.t(R.lifetime(:a)), R.vec(NativeEvent.t())) ::
          R.nif_result(R.vec(term()))
  @cfg feature: "native-test"
  defrustp encode_pending_events(env, pending) do
    pending.into_iter().map(fn event -> encode_native_event(env, event) end).collect()
  end

  @spec items() :: [RustQ.Rust.AST.item()]
  def items, do: Enum.map(MetaAST.functions(__MODULE__), &%{&1 | vis: :crate})
end
