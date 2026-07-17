use crate::*;

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
    let tree = window_tree(window)?;
    let shared_window = Arc::new(WindowState::new(tree));
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);

    let command = WindowCommand::Open {
        runtime_id: runtime.id,
        title: title.clone(),
        window_id,
        width,
        height,
        window_state: shared_window,
        runtime: runtime.state.clone(),
        reply,
    };

    match execute_window_command(&runtime, command, receiver) {
        Ok(()) => Ok((atoms::ok(), title).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn open_window_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _window: Term<'a>,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

    match execute_window_command(&runtime, command, receiver) {
        Ok(()) => Ok((atoms::ok(), window_id).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn update_window_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _window_id: u64,
    _tree: Term<'a>,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

    match execute_window_command(&runtime, command, receiver) {
        Ok(()) => Ok((atoms::ok(), window_id).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn close_window_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _window_id: u64,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

    match execute_window_command_with_timeout(
        &runtime,
        command,
        receiver,
        std::time::Duration::from_millis(timeout_ms),
    ) {
        Ok(()) => Ok((atoms::ok(), window_id).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn await_frame_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _window_id: u64,
    _timeout_ms: u64,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

    match execute_window_command_with_timeout(
        &runtime,
        command,
        receiver,
        std::time::Duration::from_secs(5),
    ) {
        Ok(generation) => Ok((atoms::ok(), generation).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn frame_token_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _window_id: u64,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

    match execute_window_command_with_timeout(
        &runtime,
        command,
        receiver,
        std::time::Duration::from_millis(timeout_ms),
    ) {
        Ok(()) => Ok((atoms::ok(), window_id).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn await_frame_after_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _window_id: u64,
    _generation: u64,
    _timeout_ms: u64,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

    match execute_window_command(&runtime, command, receiver) {
        Ok(()) => Ok((atoms::ok(), mode).encode(env)),
        Err(reason) => Ok((atoms::error(), reason).encode(env)),
    }
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn set_theme_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _mode: Atom,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn put_resource_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _resource_id: String,
    _resource: Term<'a>,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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

#[cfg(not(feature = "real-gpui"))]
pub(crate) fn drop_resource_impl<'a>(
    _env: Env<'a>,
    _runtime: ResourceArc<RuntimeResource>,
    _resource_id: String,
) -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
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
        "change" | "release" | "search" | "keydown" | "keyup" => {
            let event_name = event.map_get(atoms::event())?.decode::<String>()?;
            let value = event.map_get(atoms::value()).ok().and_then(|term| {
                term.decode::<String>()
                    .map(EventValue::String)
                    .or_else(|_| term.decode::<Vec<String>>().map(EventValue::Strings))
                    .or_else(|_| term.decode::<bool>().map(EventValue::Boolean))
                    .or_else(|_| term.decode::<f64>().map(EventValue::Number))
                    .or_else(|_| {
                        term.decode::<i64>()
                            .map(|value| EventValue::Number(value as f64))
                    })
                    .or_else(|_| {
                        term.decode::<Atom>().and_then(|atom| {
                            if atom == atoms::nil() {
                                Ok(EventValue::Nil)
                            } else {
                                Err(rustler::Error::BadArg)
                            }
                        })
                    })
                    .ok()
            });
            let kind = match event_type.as_str() {
                "change" => InputKind::Change,
                "release" => InputKind::Release,
                "search" => InputKind::Search,
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

#[cfg(feature = "real-gpui")]
pub(crate) fn window_id(window: Term) -> NifResult<u64> {
    window.map_get(atoms::id())?.decode::<u64>()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn window_size(window: Term) -> NifResult<(f32, f32)> {
    let Ok(size) = window.map_get(atoms::size()) else {
        return Ok((800.0, 600.0));
    };
    let size = size.decode::<Vec<u32>>()?;

    match size.as_slice() {
        [width, height] if *width > 0 && *height > 0 => Ok((*width as f32, *height as f32)),
        _other => Err(rustler::Error::BadArg),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn window_title(window: Term) -> NifResult<String> {
    window.map_get(atoms::title())?.decode::<String>()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn window_tree(window: Term) -> NifResult<ElementNode> {
    let root = window.map_get(atoms::root())?;

    match root.map_get(atoms::tree()) {
        Ok(tree) => decode_element_node(tree),
        Err(_error) => Ok(ElementNode::empty_root()),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_element_node(term: Term) -> NifResult<ElementNode> {
    if let Ok(text) = term.decode::<String>() {
        return Ok(ElementNode::Text(TextNode {
            text,
            style: StyleAttrs::default(),
        }));
    }

    let type_term = term.map_get(atoms::type_atom())?;
    let node_type = type_term.atom_to_string()?;

    let tag = decode_generated_element_tag(node_type.as_str());

    decode_generated_element_node(term, tag)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_container_node(
    term: Term,
    tag: GeneratedElementTag,
) -> NifResult<ElementNode> {
    Ok(ElementNode::Div(ContainerNode {
        tag,
        style: decode_style(term)?,
        children: decode_children(term)?,
        click: string_attr(term, atoms::phx_click()),
    }))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_select_options(term: Term) -> NifResult<Vec<SelectOptionNode>> {
    let attrs = term.map_get(atoms::attrs())?;
    let options = attrs.map_get(atoms::options())?.decode::<Vec<Term>>()?;
    let mut values = HashSet::new();

    options
        .into_iter()
        .map(|option| {
            let label = option.map_get(atoms::label())?.decode::<String>()?;
            let value = option.map_get(atoms::value())?.decode::<String>()?;
            if label.is_empty() || value.is_empty() || !values.insert(value.clone()) {
                return Err(rustler::Error::BadArg);
            }
            Ok(SelectOptionNode { label, value })
        })
        .collect()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_radio_options(term: Term) -> NifResult<Vec<RadioOptionNode>> {
    let attrs = term.map_get(atoms::attrs())?;
    let options = attrs.map_get(atoms::options())?.decode::<Vec<Term>>()?;
    let mut values = HashSet::new();

    options
        .into_iter()
        .map(|option| {
            let label = option.map_get(atoms::label())?.decode::<String>()?;
            let value = option.map_get(atoms::value())?.decode::<String>()?;
            let disabled = option
                .map_get(atoms::disabled())
                .ok()
                .and_then(|term| term.decode::<bool>().ok())
                .unwrap_or(false);
            if label.is_empty() || value.is_empty() || !values.insert(value.clone()) {
                return Err(rustler::Error::BadArg);
            }
            Ok(RadioOptionNode {
                label,
                value,
                disabled,
            })
        })
        .collect()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_input_node(term: Term, _tag: GeneratedElementTag) -> NifResult<ElementNode> {
    Ok(ElementNode::Input(InputNode {
        style: decode_style(term)?,
        value: string_attr(term, atoms::value()).unwrap_or_default(),
        placeholder: string_attr(term, atoms::placeholder()),
        change: string_attr(term, atoms::phx_change()),
        keydown: string_attr(term, atoms::phx_keydown()),
        keyup: string_attr(term, atoms::phx_keyup()),
    }))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_children(term: Term) -> NifResult<Vec<ElementNode>> {
    let children = term.map_get(atoms::children())?.decode::<Vec<Term>>()?;

    children.into_iter().map(decode_element_node).collect()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_text_children(term: Term) -> NifResult<String> {
    let children = term.map_get(atoms::children())?.decode::<Vec<Term>>()?;

    let mut text = String::new();

    for child in children {
        text.push_str(&text_fragment(child)?);
    }

    Ok(text)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn string_attr(term: Term, attr: Atom) -> Option<String> {
    let attrs = term.map_get(atoms::attrs()).ok()?;
    attrs.map_get(attr).ok()?.decode::<String>().ok()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn component_id(term: Term) -> NifResult<String> {
    match component_string_attr(term, atoms::id())? {
        Some(id) if !id.is_empty() => Ok(id),
        _other => Err(rustler::Error::BadArg),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn component_string_attr(term: Term, attr: Atom) -> NifResult<Option<String>> {
    let attrs = term.map_get(atoms::attrs())?;
    match attrs.map_get(attr) {
        Ok(value) => value.decode::<String>().map(Some),
        Err(_missing) => Ok(None),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn component_bool_attr(term: Term, attr: Atom) -> NifResult<Option<bool>> {
    let attrs = term.map_get(atoms::attrs())?;
    match attrs.map_get(attr) {
        Ok(value) => value.decode::<bool>().map(Some),
        Err(_missing) => Ok(None),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn component_number_attr(term: Term, attr: Atom) -> NifResult<Option<f64>> {
    let attrs = term.map_get(atoms::attrs())?;
    match attrs.map_get(attr) {
        Ok(value) => {
            let number = value
                .decode::<f64>()
                .or_else(|_| value.decode::<i64>().map(|number| number as f64))?;
            if number.is_finite() {
                Ok(Some(number))
            } else {
                Err(rustler::Error::BadArg)
            }
        }
        Err(_missing) => Ok(None),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn component_string_list_attr(term: Term, attr: Atom) -> NifResult<Vec<String>> {
    let attrs = term.map_get(atoms::attrs())?;
    match attrs.map_get(attr) {
        Ok(value) => value.decode::<Vec<String>>(),
        Err(_missing) => Ok(Vec::new()),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn component_enum_attr(
    term: Term,
    attr: Atom,
    allowed: &[&str],
) -> NifResult<Option<String>> {
    match component_string_attr(term, attr)? {
        Some(value) if allowed.contains(&value.as_str()) => Ok(Some(value)),
        Some(_invalid) => Err(rustler::Error::BadArg),
        None => Ok(None),
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_image_node(term: Term, _tag: GeneratedElementTag) -> NifResult<ElementNode> {
    let attrs = term.map_get(atoms::attrs())?;
    let raster = attrs.map_get(atoms::raster())?;

    if let Ok(type_term) = raster.map_get(atoms::__type__()) {
        if type_term
            .atom_to_string()
            .is_ok_and(|value| value == "resource_ref")
        {
            let id = decode_resource_ref(raster)?;
            return Ok(ElementNode::Image(ImageNode {
                image: ImageData::Ref(id),
                style: decode_style(term)?,
            }));
        }
    }

    let raster = decode_raster_resource(raster)?;
    raster.validate()?;
    Ok(ElementNode::Image(ImageNode {
        image: ImageData::Raster(raster),
        style: decode_style(term)?,
    }))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_text_node(term: Term, _tag: GeneratedElementTag) -> NifResult<ElementNode> {
    Ok(ElementNode::Text(TextNode {
        text: decode_text_children(term)?,
        style: decode_style(term)?,
    }))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_style(term: Term) -> NifResult<StyleAttrs> {
    let attrs = term.map_get(atoms::attrs())?;
    let mut decoded = StyleAttrs::default();
    let Ok(style) = attrs.map_get(atoms::style()) else {
        return Ok(decoded);
    };
    let entries = style.decode::<Vec<(Term, Term)>>()?;

    for (key, value) in entries {
        if !apply_generated_style_attr(&mut decoded, key.decode::<Atom>()?, value) {
            return Err(rustler::Error::BadArg);
        }
    }

    Ok(decoded)
}
