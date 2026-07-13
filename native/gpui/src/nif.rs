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
    let title = window_title(env, window)?;
    let window_id = window_id(env, window).unwrap_or(1);
    let tree = window_tree(window).unwrap_or_else(ElementNode::empty_root);
    let shared_window = Arc::new(WindowState {
        tree: Mutex::new(tree),
    });
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);

    let command = WindowCommand::Open {
        runtime_id: runtime.id,
        title: title.clone(),
        window_id,
        window_state: shared_window,
        runtime: runtime.clone(),
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
pub(crate) fn stop_runtime_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
) -> NifResult<Term<'a>> {
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    let command = WindowCommand::ShutdownRuntime {
        runtime_id: runtime.id,
        reply,
    };

    match execute_window_command(&runtime, command, receiver) {
        Ok(()) => {
            runtime
                .resources
                .lock()
                .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
                .clear();
            runtime
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
fn execute_window_command(
    runtime: &ResourceArc<RuntimeResource>,
    command: WindowCommand,
    receiver: std::sync::mpsc::Receiver<Result<(), String>>,
) -> Result<(), String> {
    runtime
        .command_tx
        .unbounded_send(command)
        .map_err(|_| "gpui_runtime_stopped".to_string())?;

    match receiver.recv_timeout(std::time::Duration::from_secs(5)) {
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
    let window_id = event
        .map_get(Atom::from_bytes(env, b"window_id")?)?
        .decode::<u64>()?;
    let event_name = event
        .map_get(Atom::from_bytes(env, b"event")?)?
        .decode::<String>()?;
    let event_type = event
        .map_get(Atom::from_bytes(env, b"type")?)
        .ok()
        .and_then(|term| term.atom_to_string().ok())
        .unwrap_or_else(|| "click".to_string());
    let value = event
        .map_get(Atom::from_bytes(env, b"value")?)
        .ok()
        .and_then(|term| term.decode::<String>().ok());

    if event_type == "click" {
        push_event(
            &runtime,
            NativeEvent::Click {
                window_id,
                event: event_name,
            },
        )?;
    } else {
        push_event(
            &runtime,
            NativeEvent::Input {
                kind: event_type,
                window_id,
                event: event_name,
                value,
            },
        )?;
    }
    Ok((atoms::ok(), atoms::ok()).encode(env))
}

pub(crate) fn validate_tree_impl<'a>(env: Env<'a>, tree: Term<'a>) -> NifResult<Term<'a>> {
    if tree.is_map() {
        Ok((atoms::ok(), tree).encode(env))
    } else {
        Ok((atoms::error(), atoms::invalid_tree()).encode(env))
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn window_id(env: Env, window: Term) -> Option<u64> {
    window
        .map_get(Atom::from_bytes(env, b"id").ok()?)
        .ok()
        .and_then(|term| term.decode::<u64>().ok())
}

#[cfg(feature = "real-gpui")]
pub(crate) fn window_title(env: Env, window: Term) -> NifResult<String> {
    let title_atom = Atom::from_bytes(env, b"title")?;

    Ok(window
        .map_get(title_atom)
        .ok()
        .and_then(|term| term.decode::<String>().ok())
        .unwrap_or_else(|| "GPUI + Elixir".to_string()))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn window_tree(window: Term) -> Option<ElementNode> {
    let env = window.get_env();
    let root = window.map_get(Atom::from_bytes(env, b"root").ok()?).ok()?;
    let tree = root.map_get(Atom::from_bytes(env, b"tree").ok()?).ok()?;
    decode_element_node(tree).ok()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_element_node(term: Term) -> NifResult<ElementNode> {
    if let Ok(text) = term.decode::<String>() {
        return Ok(ElementNode::Text {
            text,
            style: StyleAttrs::default(),
        });
    }

    let env = term.get_env();
    let type_term = term.map_get(Atom::from_bytes(env, b"type")?)?;
    let node_type = type_term.atom_to_string()?;

    let tag = decode_generated_element_tag(node_type.as_str());

    match generated_component_kind(tag) {
        GeneratedComponentKind::Container => decode_container(term, tag),
        GeneratedComponentKind::Input => decode_input(term),
        GeneratedComponentKind::Image => decode_image(term),
        GeneratedComponentKind::Text => Ok(ElementNode::Text {
            text: decode_text_children(term)?,
            style: decode_style(term).unwrap_or_default(),
        }),
        GeneratedComponentKind::Unknown => Ok(ElementNode::Text {
            text: String::new(),
            style: StyleAttrs::default(),
        }),
    }
}

#[cfg(feature = "real-gpui")]
fn decode_container(term: Term, tag: GeneratedElementTag) -> NifResult<ElementNode> {
    Ok(ElementNode::Div {
        tag,
        style: decode_style(term).unwrap_or_default(),
        children: decode_children(term).unwrap_or_default(),
        click: string_attr(term, "phx-click"),
    })
}

#[cfg(feature = "real-gpui")]
fn decode_input(term: Term) -> NifResult<ElementNode> {
    Ok(ElementNode::Input {
        style: decode_style(term).unwrap_or_default(),
        value: string_attr(term, "value").unwrap_or_default(),
        placeholder: string_attr(term, "placeholder"),
        change: string_attr(term, "phx-change"),
        keydown: string_attr(term, "phx-keydown"),
        keyup: string_attr(term, "phx-keyup"),
    })
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_children(term: Term) -> NifResult<Vec<ElementNode>> {
    let children = term
        .map_get(Atom::from_bytes(term.get_env(), b"children")?)?
        .decode::<Vec<Term>>()?;

    Ok(children
        .into_iter()
        .filter_map(|child| decode_element_node(child).ok())
        .collect())
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_text_children(term: Term) -> NifResult<String> {
    let children = term
        .map_get(Atom::from_bytes(term.get_env(), b"children")?)?
        .decode::<Vec<Term>>()?;

    let mut text = String::new();

    for child in children {
        if let Ok(fragment) = child.decode::<String>() {
            text.push_str(&fragment);
        }
    }

    Ok(text)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn string_attr(term: Term, attr: &str) -> Option<String> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs").ok()?).ok()?;
    attrs
        .map_get(Atom::from_bytes(env, attr.as_bytes()).ok()?)
        .ok()?
        .decode::<String>()
        .ok()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_image(term: Term) -> NifResult<ElementNode> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs")?)?;
    let raster = attrs.map_get(Atom::from_bytes(env, b"raster")?)?;

    if let Ok(type_term) = raster.map_get(Atom::from_bytes(env, b"__type__")?) {
        if type_term
            .atom_to_string()
            .is_ok_and(|value| value == "resource_ref")
        {
            return decode_resource_ref(raster).map(|id| ElementNode::Image {
                image: ImageData::Ref(id),
                style: decode_style(term).unwrap_or_default(),
            });
        }
    }

    let raster = decode_raster_resource(raster)?;
    raster.validate()?;
    Ok(ElementNode::Image {
        image: ImageData::Raster(raster),
        style: decode_style(term).unwrap_or_default(),
    })
}

#[cfg(feature = "real-gpui")]
pub(crate) fn decode_style(term: Term) -> NifResult<StyleAttrs> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs")?)?;
    let style = attrs.map_get(Atom::from_bytes(env, b"style")?)?;
    let entries = style.decode::<Vec<(Term, Term)>>()?;
    let mut attrs = StyleAttrs::default();

    for (key, value) in entries {
        let key = key.atom_to_string()?;
        apply_generated_style_attr(&mut attrs, key.as_str(), value);
    }

    Ok(attrs)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn atom_eq(term: Term, expected: &str) -> bool {
    term.atom_to_string().is_ok_and(|value| value == expected)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn atom_string(term: Term) -> Option<String> {
    term.atom_to_string().ok()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn rgb_value(term: Term) -> Option<u32> {
    let values = term.decode::<Vec<Term>>().ok()?;
    if values.len() != 2 || !atom_eq(values[0], "rgb") {
        return None;
    }

    values[1].decode::<u32>().ok()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn number_value(term: Term) -> Option<f32> {
    term.decode::<f64>()
        .ok()
        .map(|value| value as f32)
        .or_else(|| term.decode::<i64>().ok().map(|value| value as f32))
}

#[cfg(feature = "real-gpui")]
pub(crate) fn px_value(term: Term) -> Option<f32> {
    let values = term.decode::<Vec<Term>>().ok()?;
    if values.len() != 2 || !atom_eq(values[0], "px") {
        return None;
    }

    values[1].decode::<f64>().ok().map(|value| value as f32)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn radius_value(term: Term) -> Option<f32> {
    if atom_eq(term, "full") {
        return Some(9999.0);
    }

    px_value(term)
}
