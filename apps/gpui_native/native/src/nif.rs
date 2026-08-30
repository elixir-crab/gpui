use crate::*;

#[cfg(feature = "real-gpui")]
const MAX_WINDOW_COMMANDS: usize = 64;

pub(crate) fn host_info_impl<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    #[cfg(feature = "gpui-component-host")]
    let host = atoms::gpui_component();

    #[cfg(all(feature = "vanilla-host", not(feature = "gpui-component-host")))]
    let host = atoms::vanilla();

    #[cfg(not(any(feature = "vanilla-host", feature = "gpui-component-host")))]
    let host = atoms::headless();

    Ok((atoms::ok(), host).encode(env))
}

pub(crate) fn text_buffer_new_impl<'a>(
    env: Env<'a>,
    text: String,
    revision: u64,
    selections: Vec<TextSelection>,
) -> NifResult<Term<'a>> {
    match TextBufferResource::new(text, revision, selections) {
        Ok(buffer) => Ok((atoms::ok(), ResourceArc::new(buffer)).encode(env)),
        Err(error) => encode_text_buffer_error(env, error),
    }
}

pub(crate) fn text_buffer_snapshot_impl<'a>(
    env: Env<'a>,
    buffer: ResourceArc<TextBufferResource>,
) -> NifResult<Term<'a>> {
    encode_text_buffer_result(env, buffer.snapshot())
}

pub(crate) fn text_buffer_transact_impl<'a>(
    env: Env<'a>,
    buffer: ResourceArc<TextBufferResource>,
    transaction: TextTransaction,
) -> NifResult<Term<'a>> {
    encode_text_buffer_result(env, buffer.transact(transaction))
}

pub(crate) fn text_buffer_undo_impl<'a>(
    env: Env<'a>,
    buffer: ResourceArc<TextBufferResource>,
    base_revision: u64,
) -> NifResult<Term<'a>> {
    encode_text_buffer_result(env, buffer.undo(base_revision))
}

pub(crate) fn text_buffer_redo_impl<'a>(
    env: Env<'a>,
    buffer: ResourceArc<TextBufferResource>,
    base_revision: u64,
) -> NifResult<Term<'a>> {
    encode_text_buffer_result(env, buffer.redo(base_revision))
}

fn encode_text_buffer_result<'a, T: Encoder>(
    env: Env<'a>,
    result: Result<T, TextBufferError>,
) -> NifResult<Term<'a>> {
    match result {
        Ok(value) => Ok((atoms::ok(), value).encode(env)),
        Err(error) => encode_text_buffer_error(env, error),
    }
}

fn encode_text_buffer_error<'a>(env: Env<'a>, error: TextBufferError) -> NifResult<Term<'a>> {
    let reason = match error {
        TextBufferError::InvalidPosition => atoms::invalid_position().encode(env),
        TextBufferError::InvalidRange => atoms::invalid_range().encode(env),
        TextBufferError::InvalidSelection => atoms::invalid_selection().encode(env),
        TextBufferError::OverlappingEdits => atoms::overlapping_edits().encode(env),
        TextBufferError::StaleRevision(current) => {
            return Ok((atoms::error(), (atoms::stale_revision(), current)).encode(env));
        }
        TextBufferError::TransactionConflict => atoms::transaction_conflict().encode(env),
        TextBufferError::NothingToUndo => atoms::nothing_to_undo().encode(env),
        TextBufferError::NothingToRedo => atoms::nothing_to_redo().encode(env),
        #[cfg(feature = "components")]
        TextBufferError::NoChange => atoms::transaction_conflict().encode(env),
        TextBufferError::LockFailed => atoms::text_buffer_lock_failed().encode(env),
    };
    Ok((atoms::error(), reason).encode(env))
}

pub(crate) fn decode_image_impl<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
    let (width, height, data) = match gpui_core::image_decode::decode(bytes.as_slice()) {
        Ok(decoded) => decoded,
        Err(_error) => return Ok((atoms::error(), "invalid_image").encode(env)),
    };
    let mut binary = rustler::OwnedBinary::new(data.len())
        .ok_or_else(|| rustler::Error::Term(Box::new("image_allocation_failed")))?;
    binary.as_mut_slice().copy_from_slice(&data);

    Ok((atoms::ok(), width, height, binary.release(env)).encode(env))
}

pub(crate) fn start_runtime_impl<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    #[cfg(feature = "real-gpui")]
    let runtime = ResourceArc::new(
        RuntimeResource::new().map_err(|reason| rustler::Error::Term(Box::new(reason)))?,
    );

    #[cfg(not(feature = "real-gpui"))]
    let runtime = ResourceArc::new(RuntimeResource::new());

    Ok((atoms::ok(), runtime).encode(env))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn open_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window: Term<'a>,
) -> NifResult<Term<'a>> {
    let decoded = window.decode::<Decoded>()?;
    let config = normalize(decoded)?;
    let Config {
        id: window_id,
        title,
        width,
        height,
        min_width,
        min_height,
        resizable,
        content_chrome,
        close_request,
        focus,
        blur,
        commands,
        tree,
    } = config;
    let tree = decode_element_node(tree)?;
    let min_size = min_width.zip(min_height);
    let commands = validate_window_commands(commands)?;
    let shared_window = Arc::new(WindowState::new(tree, commands));
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);

    let command = WindowCommand::Open {
        runtime_id: runtime.id,
        title: title.clone(),
        window_id,
        width,
        height,
        min_size,
        resizable,
        content_chrome,
        close_request,
        focus,
        blur,
        window_state: shared_window,
        runtime: runtime.state.clone(),
        reply,
    };

    encode_command_result(
        env,
        execute_window_command(&runtime, command, receiver).map(|()| title),
    )
}

#[cfg(feature = "real-gpui")]
fn validate_window_commands(commands: Vec<(String, String)>) -> NifResult<Vec<CommandBinding>> {
    if commands.len() > MAX_WINDOW_COMMANDS {
        return Err(rustler::Error::BadArg);
    }

    let mut ids = HashSet::new();
    let mut shortcuts = HashSet::new();
    commands
        .into_iter()
        .map(|(id, shortcut)| {
            if !ids.insert(id.clone()) || !shortcuts.insert(shortcut.clone()) {
                return Err(rustler::Error::BadArg);
            }

            CommandBinding::new(id, shortcut).map_err(|_reason| rustler::Error::BadArg)
        })
        .collect()
}

pub(crate) fn drain_events_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
) -> NifResult<Term<'a>> {
    let mut events = runtime
        .state
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?;
    let drained = std::mem::take(&mut *events);
    let encoded = drained
        .into_iter()
        .map(|event| encode_native_event(env, event))
        .collect::<NifResult<Vec<Term>>>()?;
    Ok((atoms::ok(), encoded).encode(env))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn update_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: UpdateRequest<'a>,
) -> NifResult<Term<'a>> {
    let (window_id, tree) = decode_update(request)?;
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::Update {
        runtime_id: runtime.id,
        window_id,
        tree: Box::new(tree),
        reply,
    };

    encode_command_result(
        env,
        execute_window_command(&runtime, command, receiver).map(|()| window_id),
    )
}

#[cfg(feature = "real-gpui")]
pub(crate) fn close_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: CloseRequest,
) -> NifResult<Term<'a>> {
    let window_id = decode_close(request);
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::Close {
        runtime_id: runtime.id,
        window_id,
        reply,
    };

    encode_command_result(
        env,
        execute_window_command(&runtime, command, receiver).map(|()| window_id),
    )
}

#[cfg(feature = "real-gpui")]
pub(crate) fn await_frame_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: FrameRequest,
) -> NifResult<Term<'a>> {
    let FrameRequest {
        window_id,
        timeout_ms,
    } = request;
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::AwaitFrame {
        runtime_id: runtime.id,
        window_id,
        reply,
    };

    encode_command_result(
        env,
        execute_window_command_with_timeout(
            &runtime,
            command,
            receiver,
            std::time::Duration::from_millis(timeout_ms),
        )
        .map(|()| window_id),
    )
}

#[cfg(feature = "real-gpui")]
pub(crate) fn frame_token_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: CloseRequest,
) -> NifResult<Term<'a>> {
    let window_id = decode_close(request);
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::FrameToken {
        runtime_id: runtime.id,
        window_id,
        reply,
    };

    encode_command_result(
        env,
        execute_window_command_with_timeout(
            &runtime,
            command,
            receiver,
            std::time::Duration::from_secs(5),
        ),
    )
}

#[cfg(feature = "real-gpui")]
pub(crate) fn await_frame_after_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: FrameAfterRequest,
) -> NifResult<Term<'a>> {
    let FrameAfterRequest {
        window_id,
        generation,
        timeout_ms,
    } = request;
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::AwaitFrameAfter {
        runtime_id: runtime.id,
        window_id,
        generation,
        reply,
    };

    encode_command_result(
        env,
        execute_window_command_with_timeout(
            &runtime,
            command,
            receiver,
            std::time::Duration::from_millis(timeout_ms),
        )
        .map(|()| window_id),
    )
}

#[cfg(feature = "real-gpui")]
pub(crate) fn stop_runtime_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
) -> NifResult<Term<'a>> {
    use std::sync::atomic::Ordering;

    if runtime.stopped.load(Ordering::Acquire) {
        return Ok((atoms::ok(), atoms::ok()).encode(env));
    }

    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::ShutdownRuntime {
        runtime_id: runtime.id,
        reply: Some(reply),
    };

    match execute_window_command(&runtime, command, receiver) {
        Ok(()) => {
            runtime.stopped.store(true, Ordering::Release);
            runtime
                .state
                .resources
                .lock()
                .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
                .clear();
            runtime
                .state
                .input_values
                .lock()
                .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
                .clear();
            Ok((atoms::ok(), atoms::ok()).encode(env))
        }
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn stop_runtime_impl<'a>(
    env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
) -> NifResult<Term<'a>> {
    Ok((atoms::ok(), atoms::ok()).encode(env))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn set_theme_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    mode: Theme,
) -> NifResult<Term<'a>> {
    let (native_mode, encoded_mode) = match mode {
        Theme::Light => (NativeThemeMode::Light, atoms::light()),
        Theme::Dark => (NativeThemeMode::Dark, atoms::dark()),
    };
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::SetTheme {
        mode: native_mode,
        reply,
    };

    encode_command_result(
        env,
        execute_window_command(&runtime, command, receiver).map(|()| encoded_mode),
    )
}

pub(crate) fn native_test_start_impl<'a>(
    env: Env<'a>,
    width: f64,
    height: f64,
) -> NifResult<Term<'a>> {
    #[cfg(feature = "native-test")]
    let result = native_test::start(width as f32, height as f32).map(ResourceArc::new);
    #[cfg(not(feature = "native-test"))]
    let _ = (width, height);
    #[cfg(not(feature = "native-test"))]
    let result: Result<ResourceArc<native_test::NativeTestSessionResource>, String> =
        Err("native_test_disabled".to_string());
    encode_command_result(env, result)
}

pub(crate) fn native_test_render_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: RenderRequest<'a>,
) -> NifResult<Term<'a>> {
    let tree = request.tree;
    #[cfg(feature = "native-test")]
    let result = decode_element_node(tree).and_then(|tree| {
        native_test::render(&test_id, tree).map_err(|reason| rustler::Error::Term(Box::new(reason)))
    });
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, tree);
    #[cfg(not(feature = "native-test"))]
    let result: NifResult<()> = Err(rustler::Error::Term(Box::new("native_test_disabled")));
    match result {
        Ok(()) => Ok((atoms::ok(), atoms::ok()).encode(env)),
        Err(error) => Err(error),
    }
}

pub(crate) fn native_test_focus_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: TargetRequest,
) -> NifResult<Term<'a>> {
    let component_id = request.target;
    #[cfg(feature = "native-test")]
    let result = native_test::focus(&test_id, component_id);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, component_id);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_click_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: TargetRequest,
) -> NifResult<Term<'a>> {
    let element_id = request.target;
    #[cfg(feature = "native-test")]
    let result = native_test::click(&test_id, element_id);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, element_id);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_click_at_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: PointRequest,
) -> NifResult<Term<'a>> {
    let PointRequest { x, y } = request;
    #[cfg(feature = "native-test")]
    let result = native_test::click_at(&test_id, x as f32, y as f32);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, x, y);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_scroll_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: ScrollRequest,
) -> NifResult<Term<'a>> {
    let ScrollRequest {
        target: element_id,
        delta_x,
        delta_y,
    } = request;
    #[cfg(feature = "native-test")]
    let result = native_test::scroll(&test_id, element_id, delta_x as f32, delta_y as f32);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, element_id, delta_x, delta_y);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_input_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: InputRequest,
) -> NifResult<Term<'a>> {
    let text = request.text;
    #[cfg(feature = "native-test")]
    let result = native_test::input(&test_id, text);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, text);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_resize_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: ResizeRequest,
) -> NifResult<Term<'a>> {
    let ResizeRequest { width, height } = request;
    #[cfg(feature = "native-test")]
    let result = native_test::resize(&test_id, width as f32, height as f32);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, width, height);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_bounds_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: TargetRequest,
) -> NifResult<Term<'a>> {
    let element_id = request.target;
    #[cfg(feature = "native-test")]
    let result = native_test::bounds(&test_id, element_id);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, element_id);
    #[cfg(not(feature = "native-test"))]
    let result: Result<native_test::TestBounds, String> = Err("native_test_disabled".to_string());
    match result {
        Ok(bounds) => {
            Ok((atoms::ok(), bounds.x, bounds.y, bounds.width, bounds.height).encode(env))
        }
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

pub(crate) fn native_test_idle_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
) -> NifResult<Term<'a>> {
    #[cfg(feature = "native-test")]
    let result = native_test::idle(&test_id);
    #[cfg(not(feature = "native-test"))]
    let _ = test_id;
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_advance_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: AdvanceRequest,
) -> NifResult<Term<'a>> {
    let milliseconds = request.milliseconds;
    #[cfg(feature = "native-test")]
    let result = native_test::advance(&test_id, milliseconds);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, milliseconds);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_key_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
    request: KeyRequest,
) -> NifResult<Term<'a>> {
    let key = request.key;
    #[cfg(feature = "native-test")]
    let result = native_test::key(&test_id, key);
    #[cfg(not(feature = "native-test"))]
    let _ = (test_id, key);
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

pub(crate) fn native_test_events_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
) -> NifResult<Term<'a>> {
    #[cfg(feature = "native-test")]
    let result = native_test::events(&test_id);
    #[cfg(not(feature = "native-test"))]
    let _ = test_id;
    #[cfg(not(feature = "native-test"))]
    let result: Result<Vec<NativeEvent>, String> = Err("native_test_disabled".to_string());
    match result {
        Ok(events) => {
            let encoded = events
                .into_iter()
                .map(|event| encode_native_event(env, event))
                .collect::<NifResult<Vec<Term>>>()?;
            Ok((atoms::ok(), encoded).encode(env))
        }
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

pub(crate) fn native_test_stop_impl<'a>(
    env: Env<'a>,
    test_id: ResourceArc<native_test::NativeTestSessionResource>,
) -> NifResult<Term<'a>> {
    #[cfg(feature = "native-test")]
    let result = native_test::stop(&test_id);
    #[cfg(not(feature = "native-test"))]
    let _ = test_id;
    #[cfg(not(feature = "native-test"))]
    let result: Result<(), String> = Err("native_test_disabled".to_string());
    encode_command_result(env, result.map(|()| atoms::ok()))
}

fn encode_command_result<T: Encoder>(env: Env, result: Result<T, String>) -> NifResult<Term> {
    match result {
        Ok(value) => Ok((atoms::ok(), value).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(feature = "real-gpui")]
fn execute_window_command(
    runtime: &ResourceArc<RuntimeResource>,
    command: WindowCommand,
    receiver: std::sync::mpsc::Receiver<Result<(), String>>,
) -> Result<(), String> {
    execute_window_command_with_timeout(
        runtime,
        command,
        receiver,
        std::time::Duration::from_secs(5),
    )
}

#[cfg(feature = "real-gpui")]
fn execute_window_command_with_timeout<T>(
    runtime: &ResourceArc<RuntimeResource>,
    command: WindowCommand,
    receiver: std::sync::mpsc::Receiver<Result<T, String>>,
    timeout: std::time::Duration,
) -> Result<T, String> {
    use std::sync::atomic::Ordering;

    if runtime.stopped.load(Ordering::Acquire) {
        return Err("gpui_runtime_stopped".to_string());
    }

    runtime
        .command_tx
        .unbounded_send(command)
        .map_err(|_| "gpui_runtime_stopped".to_string())?;

    match receiver.recv_timeout(timeout) {
        Ok(result) => result,
        Err(std::sync::mpsc::RecvTimeoutError::Timeout) => Err("gpui_command_timeout".to_string()),
        Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
            Err("gpui_runtime_stopped".to_string())
        }
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn put_resource_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: PutRequest<'a>,
) -> NifResult<Term<'a>> {
    let PutRequest {
        resource_id,
        resource,
    } = request;
    let raster = decode_raster_resource(resource)?;
    raster.validate()?;
    runtime
        .state
        .resources
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .insert(resource_id.clone(), raster);
    Ok((atoms::ok(), resource_id).encode(env))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn drop_resource_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: DropRequest,
) -> NifResult<Term<'a>> {
    let resource_id = request.resource_id;
    runtime
        .state
        .resources
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .remove(&resource_id);
    Ok((atoms::ok(), resource_id).encode(env))
}

pub(crate) fn inject_event_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    request: InjectRequest<'a>,
) -> NifResult<Term<'a>> {
    let (kind, window_id, event_name, value) = decode_inject(request)?;

    match kind {
        InjectKind::WindowCloseRequest => {
            push_event(
                &runtime.state,
                NativeEvent::WindowCloseRequest { window_id },
            )?;
        }
        InjectKind::WindowFocus | InjectKind::WindowBlur => {
            push_event(
                &runtime.state,
                NativeEvent::WindowFocus {
                    focused: kind == InjectKind::WindowFocus,
                    window_id,
                },
            )?;
        }
        InjectKind::WindowClosed => {
            push_event(&runtime.state, NativeEvent::WindowClosed { window_id })?;
        }
        InjectKind::Click => {
            let event_name = event_name.ok_or(rustler::Error::BadArg)?;
            push_event(
                &runtime.state,
                NativeEvent::Click {
                    window_id,
                    event: event_name,
                },
            )?;
        }
        InjectKind::Command => {
            let event_name = event_name.ok_or(rustler::Error::BadArg)?;
            push_event(
                &runtime.state,
                NativeEvent::Command {
                    window_id,
                    event: event_name,
                },
            )?;
        }
        InjectKind::Change
        | InjectKind::Release
        | InjectKind::Search
        | InjectKind::Submit
        | InjectKind::Keydown
        | InjectKind::Keyup => {
            let event_name = event_name.ok_or(rustler::Error::BadArg)?;
            let kind = match kind {
                InjectKind::Change => InputKind::Change,
                #[cfg(feature = "components")]
                InjectKind::Release => InputKind::Release,
                #[cfg(feature = "components")]
                InjectKind::Search => InputKind::Search,
                InjectKind::Submit => InputKind::Submit,
                InjectKind::Keydown => InputKind::KeyDown,
                InjectKind::Keyup => InputKind::KeyUp,
                _other => return Err(rustler::Error::BadArg),
            };

            push_event(
                &runtime.state,
                NativeEvent::Input {
                    kind,
                    window_id,
                    event: event_name,
                    value,
                },
            )?;
        }
    }
    Ok((atoms::ok(), atoms::ok()).encode(env))
}
