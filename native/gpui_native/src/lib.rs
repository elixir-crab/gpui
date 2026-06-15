use rustler::{Atom, Encoder, Env, NifResult, ResourceArc, Term};
use std::sync::Mutex;

#[cfg(feature = "real-gpui")]
use std::sync::atomic::{AtomicBool, Ordering};

#[cfg(feature = "real-gpui")]
static GPUI_STARTED: AtomicBool = AtomicBool::new(false);

include!("generated_atoms.rs");
include!("generated_nifs.rs");

pub struct RuntimeResource {
    events: Mutex<Vec<NativeEvent>>,
}

#[derive(Clone, Debug)]
enum NativeEvent {
    Text(String),
    Click { window_id: u64, event: String },
    WindowUpdated { window_id: u64 },
}

#[rustler::resource_impl]
impl rustler::Resource for RuntimeResource {}

fn start_runtime_impl<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    let runtime = ResourceArc::new(RuntimeResource {
        events: Mutex::new(Vec::new()),
    });

    Ok((atoms::ok(), runtime).encode(env))
}

#[cfg(not(feature = "real-gpui"))]
fn open_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window: Term<'a>,
) -> NifResult<Term<'a>> {
    let title = window_title(env, window)?;
    push_text_event(&runtime, format!("window_open_requested:{title}"))?;
    Ok((atoms::ok(), title).encode(env))
}

#[cfg(feature = "real-gpui")]
fn open_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window: Term<'a>,
) -> NifResult<Term<'a>> {
    let title = window_title(env, window)?;
    let tree = window_tree(window).unwrap_or_else(ElementNode::default_root);

    if GPUI_STARTED.swap(true, Ordering::SeqCst) {
        push_text_event(&runtime, "window_open_rejected:already_started".to_string())?;
        return Ok((atoms::error(), "gpui_already_started").encode(env));
    }

    let event_title = title.clone();
    let runtime_for_window = runtime.clone();
    std::thread::spawn(move || run_gpui_window(title, tree, runtime_for_window));
    push_text_event(&runtime, format!("window_open_requested:{event_title}"))?;

    Ok((atoms::ok(), event_title).encode(env))
}

fn drain_events_impl<'a>(env: Env<'a>, runtime: ResourceArc<RuntimeResource>) -> NifResult<Term<'a>> {
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

fn update_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
    _tree: Term<'a>,
) -> NifResult<Term<'a>> {
    push_event(&runtime, NativeEvent::WindowUpdated { window_id })?;
    Ok((atoms::ok(), window_id).encode(env))
}

fn emit_test_event_impl<'a>(
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
    push_event(&runtime, NativeEvent::Click { window_id, event: event_name })?;
    Ok((atoms::ok(), atoms::ok()).encode(env))
}

fn validate_tree_impl<'a>(env: Env<'a>, tree: Term<'a>) -> NifResult<Term<'a>> {
    if tree.is_map() {
        Ok((atoms::ok(), tree).encode(env))
    } else {
        Ok((atoms::error(), atoms::invalid_tree()).encode(env))
    }
}

fn window_title(env: Env, window: Term) -> NifResult<String> {
    let title_atom = Atom::from_bytes(env, b"title")?;

    Ok(window
        .map_get(title_atom)
        .ok()
        .and_then(|term| term.decode::<String>().ok())
        .unwrap_or_else(|| "GPUI + Elixir".to_string()))
}

fn push_text_event(runtime: &ResourceArc<RuntimeResource>, event: String) -> NifResult<()> {
    push_event(runtime, NativeEvent::Text(event))
}

fn push_event(runtime: &ResourceArc<RuntimeResource>, event: NativeEvent) -> NifResult<()> {
    runtime
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .push(event);

    Ok(())
}

fn encode_native_event<'a>(env: Env<'a>, event: NativeEvent) -> NifResult<Term<'a>> {
    match event {
        NativeEvent::Text(text) => Ok(text.encode(env)),
        NativeEvent::Click { window_id, event } => Ok(vec![
            (Atom::from_bytes(env, b"type")?, atoms::click().to_term(env)),
            (Atom::from_bytes(env, b"window_id")?, window_id.encode(env)),
            (Atom::from_bytes(env, b"event")?, event.encode(env)),
        ]
        .encode(env)),
        NativeEvent::WindowUpdated { window_id } => Ok(vec![
            (Atom::from_bytes(env, b"type")?, atoms::window_updated().to_term(env)),
            (Atom::from_bytes(env, b"window_id")?, window_id.encode(env)),
        ]
        .encode(env)),
    }
}

#[cfg(feature = "real-gpui")]
fn window_tree(window: Term) -> Option<ElementNode> {
    let env = window.get_env();
    let root = window.map_get(Atom::from_bytes(env, b"root").ok()?).ok()?;
    let tree = root.map_get(Atom::from_bytes(env, b"tree").ok()?).ok()?;
    decode_element_node(tree).ok()
}

#[cfg(feature = "real-gpui")]
fn decode_element_node(term: Term) -> NifResult<ElementNode> {
    if let Ok(text) = term.decode::<String>() {
        return Ok(ElementNode::Text(text));
    }

    let env = term.get_env();
    let type_term = term.map_get(Atom::from_bytes(env, b"type")?)?;
    let node_type = type_term.atom_to_string()?;

    match node_type.as_str() {
        "div" | "button" => Ok(ElementNode::Div {
            style: decode_style(term).unwrap_or_default(),
            children: decode_children(term).unwrap_or_default(),
            click: decode_click(term).ok().flatten(),
        }),
        "text" => Ok(ElementNode::Text(decode_text_children(term).unwrap_or_default())),
        _ => Ok(ElementNode::Text(String::new())),
    }
}

#[cfg(feature = "real-gpui")]
fn decode_children(term: Term) -> NifResult<Vec<ElementNode>> {
    let children = term
        .map_get(Atom::from_bytes(term.get_env(), b"children")?)?
        .decode::<Vec<Term>>()?;

    Ok(children
        .into_iter()
        .filter_map(|child| decode_element_node(child).ok())
        .collect())
}

#[cfg(feature = "real-gpui")]
fn decode_text_children(term: Term) -> NifResult<String> {
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
fn decode_click(term: Term) -> NifResult<Option<String>> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs")?)?;

    match attrs.map_get(Atom::from_bytes(env, b"phx-click")?) {
        Ok(value) => Ok(value.decode::<String>().ok()),
        Err(_) => Ok(None),
    }
}

#[cfg(feature = "real-gpui")]
fn decode_style(term: Term) -> NifResult<StyleAttrs> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs")?)?;
    let style = attrs.map_get(Atom::from_bytes(env, b"style")?)?;
    let entries = style.decode::<Vec<(Term, Term)>>()?;
    let mut attrs = StyleAttrs::default();

    for (key, value) in entries {
        match key.atom_to_string()?.as_str() {
            "display" => attrs.display_flex = atom_eq(value, "flex"),
            "flex_direction" => attrs.flex_direction = atom_string(value),
            "align_items" => attrs.align_items = atom_string(value),
            "justify_content" => attrs.justify_content = atom_string(value),
            "background" => attrs.background = rgb_value(value),
            "color" => attrs.color = rgb_value(value),
            "font_size" => attrs.font_size = px_value(value),
            _ => {}
        }
    }

    Ok(attrs)
}

#[cfg(feature = "real-gpui")]
fn atom_eq(term: Term, expected: &str) -> bool {
    term.atom_to_string().is_ok_and(|value| value == expected)
}

#[cfg(feature = "real-gpui")]
fn atom_string(term: Term) -> Option<String> {
    term.atom_to_string().ok()
}

#[cfg(feature = "real-gpui")]
fn rgb_value(term: Term) -> Option<u32> {
    let values = term.decode::<Vec<Term>>().ok()?;
    if values.len() != 2 || !atom_eq(values[0], "rgb") {
        return None;
    }

    values[1].decode::<u32>().ok()
}

#[cfg(feature = "real-gpui")]
fn px_value(term: Term) -> Option<f32> {
    let values = term.decode::<Vec<Term>>().ok()?;
    if values.len() != 2 || !atom_eq(values[0], "px") {
        return None;
    }

    values[1].decode::<f64>().ok().map(|value| value as f32)
}

#[cfg(feature = "real-gpui")]
#[derive(Clone, Debug, Default)]
struct StyleAttrs {
    display_flex: bool,
    flex_direction: Option<String>,
    align_items: Option<String>,
    justify_content: Option<String>,
    background: Option<u32>,
    color: Option<u32>,
    font_size: Option<f32>,
}

#[cfg(feature = "real-gpui")]
#[derive(Clone, Debug)]
enum ElementNode {
    Div { style: StyleAttrs, children: Vec<ElementNode>, click: Option<String> },
    Text(String),
}

#[cfg(feature = "real-gpui")]
impl ElementNode {
    fn default_root() -> Self {
        Self::Div {
            style: StyleAttrs {
                display_flex: true,
                flex_direction: Some("column".to_string()),
                align_items: Some("center".to_string()),
                justify_content: Some("center".to_string()),
                background: Some(0x505050),
                color: Some(0xffffff),
                font_size: Some(20.0),
            },
            children: vec![Self::Text("Hello from Elixir/OTP".to_string())],
            click: None,
        }
    }

    fn render(self, runtime: ResourceArc<RuntimeResource>, window_id: u64) -> gpui::AnyElement {
        use gpui::prelude::*;
        use gpui::{div, px, rgb, InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};

        match self {
            ElementNode::Text(text) => text.into_any_element(),
            ElementNode::Div { style, children, click } => {
                let mut element = div();

                if style.display_flex {
                    element = element.flex();
                }

                match style.flex_direction.as_deref() {
                    Some("column") => element = element.flex_col(),
                    Some("row") => element = element.flex_row(),
                    _ => {}
                }

                match style.align_items.as_deref() {
                    Some("center") => element = element.items_center(),
                    Some("start") => element = element.items_start(),
                    Some("end") => element = element.items_end(),
                    _ => {}
                }

                match style.justify_content.as_deref() {
                    Some("center") => element = element.justify_center(),
                    Some("start") => element = element.justify_start(),
                    Some("end") => element = element.justify_end(),
                    _ => {}
                }

                if let Some(color) = style.background {
                    element = element.bg(rgb(color));
                }

                if let Some(color) = style.color {
                    element = element.text_color(rgb(color));
                }

                if let Some(size) = style.font_size {
                    element = element.text_size(px(size));
                }

                for child in children {
                    element = element.child(child.render(runtime.clone(), window_id));
                }

                if let Some(event) = click {
                    let runtime_for_click = runtime.clone();
                    let element_id = format!("gpui-elixir-click-{window_id}-{event}");

                    element
                        .id(element_id)
                        .on_click(move |_event, _window, _cx| {
                            let _ = push_event(
                                &runtime_for_click,
                                NativeEvent::Click { window_id, event: event.clone() },
                            );
                        })
                        .into_any_element()
                } else {
                    element.into_any_element()
                }
            }
        }
    }
}

#[cfg(feature = "real-gpui")]
fn run_gpui_window(title: String, tree: ElementNode, runtime: ResourceArc<RuntimeResource>) {
    use gpui::{px, size, App, AppContext, Bounds, Context, Render, Window, WindowBounds, WindowOptions};

    struct ElixirRoot {
        tree: ElementNode,
        runtime: ResourceArc<RuntimeResource>,
        window_id: u64,
    }

    impl Render for ElixirRoot {
        fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl gpui::IntoElement {
            self.tree.clone().render(self.runtime.clone(), self.window_id)
        }
    }

    gpui_platform::application().run(move |cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(500.0), px(500.0)), cx);
        let tree_for_view = tree.clone();
        let runtime_for_view = runtime.clone();

        let _ = cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |window, cx| {
                window.set_window_title(&title);
                cx.new(|_| ElixirRoot {
                    tree: tree_for_view.clone(),
                    runtime: runtime_for_view.clone(),
                    window_id: 1,
                })
            },
        );

        cx.activate(true);
    });
}

rustler::init!("Elixir.GPUI.Native");
