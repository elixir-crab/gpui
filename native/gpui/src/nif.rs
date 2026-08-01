use crate::*;

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
    let (width, height, data) = match image_decode::decode(bytes.as_slice()) {
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
    let title = window_title(window)?;
    let window_id = window_id(window)?;
    let (width, height) = window_size(window)?;
    let min_size = window_optional_size(window, atoms::min_size())?;
    let resizable = window_bool(window, atoms::resizable(), true)?;
    let close_request = window_lifecycle(window, "close_request")?;
    let focus = window_lifecycle(window, "focus")?;
    let blur = window_lifecycle(window, "blur")?;
    let tree = window_tree(window)?;
    let commands = decode_window_commands(window)?;
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
fn decode_window_commands(window: Term) -> NifResult<Vec<CommandBinding>> {
    let commands = window_commands(window)?;
    if commands.len() > 64 {
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
    window_id: u64,
    tree: Term<'a>,
) -> NifResult<Term<'a>> {
    let tree = decode_element_node(tree)?;
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
    window_id: u64,
) -> NifResult<Term<'a>> {
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
    window_id: u64,
    timeout_ms: u64,
) -> NifResult<Term<'a>> {
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
    window_id: u64,
) -> NifResult<Term<'a>> {
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
    window_id: u64,
    generation: u64,
    timeout_ms: u64,
) -> NifResult<Term<'a>> {
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
    mode: Atom,
) -> NifResult<Term<'a>> {
    let native_mode = if mode == atoms::light() {
        NativeThemeMode::Light
    } else if mode == atoms::dark() {
        NativeThemeMode::Dark
    } else {
        return Err(rustler::Error::BadArg);
    };
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::SetTheme {
        mode: native_mode,
        reply,
    };

    encode_command_result(
        env,
        execute_window_command(&runtime, command, receiver).map(|()| mode),
    )
}

#[cfg(feature = "real-gpui")]
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
    resource_id: String,
    resource: Term<'a>,
) -> NifResult<Term<'a>> {
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
    resource_id: String,
) -> NifResult<Term<'a>> {
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
    event: Term<'a>,
) -> NifResult<Term<'a>> {
    let window_id = event.map_get(atoms::window_id())?.decode::<u64>()?;
    let event_type = event
        .map_get(atoms::type_atom())
        .ok()
        .and_then(|term| term.atom_to_string().ok())
        .unwrap_or_else(|| "click".to_string());

    match event_type.as_str() {
        "window_close_request" => {
            push_event(
                &runtime.state,
                NativeEvent::WindowCloseRequest { window_id },
            )?;
        }
        "window_focus" | "window_blur" => {
            push_event(
                &runtime.state,
                NativeEvent::WindowFocus {
                    focused: event_type == "window_focus",
                    window_id,
                },
            )?;
        }
        "window_closed" => {
            push_event(&runtime.state, NativeEvent::WindowClosed { window_id })?;
        }
        "click" => {
            let event_name = event.map_get(atoms::event())?.decode::<String>()?;
            push_event(
                &runtime.state,
                NativeEvent::Click {
                    window_id,
                    event: event_name,
                },
            )?;
        }
        "command" => {
            let event_name = event.map_get(atoms::event())?.decode::<String>()?;
            push_event(
                &runtime.state,
                NativeEvent::Command {
                    window_id,
                    event: event_name,
                },
            )?;
        }
        "change" | "release" | "search" | "submit" | "keydown" | "keyup" => {
            let event_name = event.map_get(atoms::event())?.decode::<String>()?;
            let value = event
                .map_get(atoms::value())
                .ok()
                .and_then(decode_event_value);
            let kind = match event_type.as_str() {
                "change" => InputKind::Change,
                "release" => InputKind::Release,
                "search" => InputKind::Search,
                "submit" => InputKind::Submit,
                "keydown" => InputKind::KeyDown,
                "keyup" => InputKind::KeyUp,
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
        _other => return Err(rustler::Error::BadArg),
    }
    Ok((atoms::ok(), atoms::ok()).encode(env))
}
