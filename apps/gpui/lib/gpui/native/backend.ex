defmodule GPUI.Native.Backend do
  @moduledoc """
  Internal adapter for the configured native backend.

  The adapter verifies backend availability before dispatch so higher-level APIs
  can return a structured error when `gpui_native` is absent. It is documented
  for maintainers but excluded from the package's public API reference.
  """

  @default_backend GPUI.Native.NIF

  @doc "Returns the configured native backend module."
  @spec module() :: module()
  def module do
    Application.get_env(:gpui, :native_backend, @default_backend)
  end

  @type backend_error :: :native_backend_unavailable

  @doc "Reports whether the configured backend loaded a native implementation."
  @spec available?() :: boolean()
  def available? do
    backend = module()

    Code.ensure_loaded?(backend) and function_exported?(backend, :compiled?, 0) and
      backend.compiled?()
  end

  @doc "Calls a backend operation or returns `{:error, :native_backend_unavailable}`."
  @spec call(atom(), [term()]) :: term()
  def call(function, arguments) when is_atom(function) and is_list(arguments) do
    if available?() do
      apply(module(), function, arguments)
    else
      {:error, :native_backend_unavailable}
    end
  end

  @doc "Decodes encoded image bytes through the configured native backend."
  def decode_image(bytes), do: call(:decode_image, [bytes])

  @doc "Creates a native text-buffer resource."
  def text_buffer_new(text, revision, selections),
    do: call(:text_buffer_new, [text, revision, selections])

  @doc "Returns a native text-buffer snapshot."
  def text_buffer_snapshot(buffer), do: call(:text_buffer_snapshot, [buffer])

  @doc "Applies a transaction to a native text buffer."
  def text_buffer_transact(buffer, transaction),
    do: call(:text_buffer_transact, [buffer, transaction])

  @doc "Undoes a native text-buffer transaction."
  def text_buffer_undo(buffer, base_revision),
    do: call(:text_buffer_undo, [buffer, base_revision])

  @doc "Redoes a native text-buffer transaction."
  def text_buffer_redo(buffer, base_revision),
    do: call(:text_buffer_redo, [buffer, base_revision])

  @doc "Returns the loaded native host identity."
  def host_info, do: call(:host_info, [])

  @doc "Sets the process-global native application identity."
  def set_app_identity(identifier, name), do: call(:set_app_identity, [identifier, name])

  @doc "Starts one native runtime namespace."
  def start_runtime, do: call(:start_runtime, [])

  @doc "Stops one native runtime namespace."
  def stop_runtime(runtime), do: call(:stop_runtime, [runtime])

  @doc "Opens a native window from a serialized window snapshot."
  def open_window(runtime, window), do: call(:open_window, [runtime, window])

  @doc "Updates one native window's element tree."
  def update_window(runtime, window_id, tree),
    do: call(:update_window, [runtime, window_id, tree])

  @doc "Closes one native window."
  def close_window(runtime, window_id), do: call(:close_window, [runtime, window_id])

  @doc "Waits for a native window frame."
  def await_frame(runtime, window_id, timeout),
    do: call(:await_frame, [runtime, window_id, timeout])

  @doc "Returns a native window's current frame generation."
  def frame_token(runtime, window_id), do: call(:frame_token, [runtime, window_id])

  @doc "Waits for a native frame newer than the supplied generation."
  def await_frame_after(runtime, window_id, generation, timeout),
    do: call(:await_frame_after, [runtime, window_id, generation, timeout])

  @doc "Changes the native component theme."
  def set_theme(runtime, mode), do: call(:set_theme, [runtime, mode])

  @doc "Installs a renderer resource in a native runtime."
  def put_resource(runtime, resource_id, resource),
    do: call(:put_resource, [runtime, resource_id, resource])

  @doc "Drops a renderer resource from a native runtime."
  def drop_resource(runtime, resource_id), do: call(:drop_resource, [runtime, resource_id])

  @doc "Drains pending native events."
  def drain_events(runtime), do: call(:drain_events, [runtime])

  @doc "Injects one normalized event into a native runtime."
  def inject_event(runtime, event), do: call(:inject_event, [runtime, event])

  @doc "Starts a deterministic native-test session."
  def native_test_start(width, height), do: call(:native_test_start, [width, height])

  @doc "Renders an element tree into a deterministic native-test session."
  def native_test_render(session, tree), do: call(:native_test_render, [session, tree])

  @doc "Resizes a deterministic native-test session."
  def native_test_resize(session, width, height),
    do: call(:native_test_resize, [session, width, height])

  @doc "Returns target bounds from a deterministic native-test session."
  def native_test_bounds(session, target), do: call(:native_test_bounds, [session, target])

  @doc "Focuses a target in a deterministic native-test session."
  def native_test_focus(session, target), do: call(:native_test_focus, [session, target])

  @doc "Clicks a target in a deterministic native-test session."
  def native_test_click(session, target), do: call(:native_test_click, [session, target])

  @doc "Clicks native-test coordinates."
  def native_test_click_at(session, x, y), do: call(:native_test_click_at, [session, x, y])

  @doc "Scrolls a target in a deterministic native-test session."
  def native_test_scroll(session, target, delta_x, delta_y),
    do: call(:native_test_scroll, [session, target, delta_x, delta_y])

  @doc "Types text into the focused deterministic native-test control."
  def native_test_input(session, text), do: call(:native_test_input, [session, text])

  @doc "Presses a semantic key in a deterministic native-test session."
  def native_test_key(session, key), do: call(:native_test_key, [session, key])

  @doc "Advances a deterministic native-test clock."
  def native_test_advance(session, milliseconds),
    do: call(:native_test_advance, [session, milliseconds])

  @doc "Runs a deterministic native-test session until idle."
  def native_test_idle(session), do: call(:native_test_idle, [session])

  @doc "Drains deterministic native-test events."
  def native_test_events(session), do: call(:native_test_events, [session])

  @doc "Stops a deterministic native-test session."
  def native_test_stop(session), do: call(:native_test_stop, [session])
end
