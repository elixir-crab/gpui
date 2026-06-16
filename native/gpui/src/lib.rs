use rustler::{Atom, Encoder, Env, NifResult, ResourceArc, Term};

#[cfg(feature = "real-gpui")]
use futures::{channel::mpsc, StreamExt};
#[cfg(feature = "real-gpui")]
use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
};
#[cfg(feature = "real-gpui")]
use zed_gpui as gpui;

mod events;
#[cfg(feature = "real-gpui")]
mod native_text_input;
#[cfg(feature = "real-gpui")]
mod raster;
mod runtime_resource;
use events::{encode_native_event, push_event, push_text_event, NativeEvent};
#[cfg(feature = "real-gpui")]
use native_text_input::NativeTextInput;
#[cfg(feature = "real-gpui")]
use raster::{ImageData, RasterData};
use runtime_resource::RuntimeResource;

include!("generated_atoms.rs");
include!("generated_element_schema.rs");
include!("generated_nifs.rs");

fn start_runtime_impl<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    let runtime = ResourceArc::new(RuntimeResource::new());
    Ok((atoms::ok(), runtime).encode(env))
}

#[cfg(feature = "real-gpui")]
fn open_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window: Term<'a>,
) -> NifResult<Term<'a>> {
    let title = window_title(env, window)?;
    let window_id = window_id(env, window).unwrap_or(1);
    let tree = window_tree(window).unwrap_or_else(ElementNode::empty_root);
    let shared_window = Arc::new(WindowState {
        tree: Mutex::new(tree),
        refresh_tx: Mutex::new(None),
        refresh_requested: AtomicBool::new(false),
    });

    runtime
        .windows
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .insert(window_id, shared_window.clone());

    let event_title = title.clone();
    let runtime_for_window = runtime.clone();
    std::thread::spawn(move || {
        run_gpui_window(title, window_id, shared_window, runtime_for_window)
    });
    push_text_event(&runtime, format!("window_open_requested:{event_title}"))?;

    Ok((atoms::ok(), event_title).encode(env))
}

fn drain_events_impl<'a>(
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
fn update_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
    tree: Term<'a>,
) -> NifResult<Term<'a>> {
    let tree = decode_element_node(tree)?;
    let windows = runtime
        .windows
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?;

    if let Some(shared_window) = windows.get(&window_id) {
        *shared_window
            .tree
            .lock()
            .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))? = tree;
        shared_window.request_refresh();
        push_event(&runtime, NativeEvent::WindowUpdated { window_id })?;
        Ok((atoms::ok(), window_id).encode(env))
    } else {
        Ok((atoms::error(), "unknown_window").encode(env))
    }
}

#[cfg(feature = "real-gpui")]
fn put_resource_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    resource_id: String,
    resource: Term<'a>,
) -> NifResult<Term<'a>> {
    let raster = RasterData::from(decode_generated_raster_resource(resource)?);
    raster.validate()?;
    runtime
        .resources
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .insert(resource_id.clone(), raster);
    Ok((atoms::ok(), resource_id).encode(env))
}

#[cfg(feature = "real-gpui")]
fn drop_resource_impl<'a>(
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

fn inject_event_impl<'a>(
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

fn validate_tree_impl<'a>(env: Env<'a>, tree: Term<'a>) -> NifResult<Term<'a>> {
    if tree.is_map() {
        Ok((atoms::ok(), tree).encode(env))
    } else {
        Ok((atoms::error(), atoms::invalid_tree()).encode(env))
    }
}

#[cfg(feature = "real-gpui")]
fn window_id(env: Env, window: Term) -> Option<u64> {
    window
        .map_get(Atom::from_bytes(env, b"id").ok()?)
        .ok()
        .and_then(|term| term.decode::<u64>().ok())
}

fn window_title(env: Env, window: Term) -> NifResult<String> {
    let title_atom = Atom::from_bytes(env, b"title")?;

    Ok(window
        .map_get(title_atom)
        .ok()
        .and_then(|term| term.decode::<String>().ok())
        .unwrap_or_else(|| "GPUI + Elixir".to_string()))
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

    decode_generated_element_node(decode_generated_element_tag(node_type.as_str()), term)
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
fn generated_string_attr(term: Term, attr: &str) -> Option<String> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs").ok()?).ok()?;
    attrs
        .map_get(Atom::from_bytes(env, attr.as_bytes()).ok()?)
        .ok()?
        .decode::<String>()
        .ok()
}

#[cfg(feature = "real-gpui")]
fn decode_raster(term: Term) -> NifResult<ImageData> {
    let env = term.get_env();
    let attrs = term.map_get(Atom::from_bytes(env, b"attrs")?)?;
    let raster = attrs.map_get(Atom::from_bytes(env, b"raster")?)?;

    if let Ok(type_term) = raster.map_get(Atom::from_bytes(env, b"__type__")?) {
        if type_term
            .atom_to_string()
            .is_ok_and(|value| value == "resource_ref")
        {
            let resource_ref = decode_generated_resource_ref_resource(raster)?;
            return Ok(ImageData::Ref(resource_ref.id));
        }
    }

    let raster = RasterData::from(decode_generated_raster_resource(raster)?);
    raster.validate()?;
    Ok(ImageData::Raster(raster))
}

#[cfg(feature = "real-gpui")]
fn decode_style(term: Term) -> NifResult<StyleAttrs> {
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
fn optional_u32(term: Option<Term>) -> Option<u32> {
    term.and_then(|term| term.decode::<u32>().ok())
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
fn radius_value(term: Term) -> Option<f32> {
    if atom_eq(term, "full") {
        return Some(9999.0);
    }

    px_value(term)
}

#[cfg(feature = "real-gpui")]
struct WindowState {
    tree: Mutex<ElementNode>,
    refresh_tx: Mutex<Option<mpsc::UnboundedSender<()>>>,
    refresh_requested: AtomicBool,
}

#[cfg(feature = "real-gpui")]
impl WindowState {
    fn install_refresh_sender(&self, refresh_tx: mpsc::UnboundedSender<()>) {
        if let Ok(mut slot) = self.refresh_tx.lock() {
            *slot = Some(refresh_tx.clone());
        }

        if self.refresh_requested.swap(false, Ordering::SeqCst) {
            let _ = refresh_tx.unbounded_send(());
        }
    }

    fn request_refresh(&self) {
        self.refresh_requested.store(true, Ordering::SeqCst);

        if let Ok(slot) = self.refresh_tx.lock() {
            if let Some(refresh_tx) = slot.as_ref() {
                let _ = refresh_tx.unbounded_send(());
            }
        }
    }
}

#[cfg(feature = "real-gpui")]
type SharedWindow = Arc<WindowState>;

#[cfg(feature = "real-gpui")]
struct ElixirRoot {
    window_state: SharedWindow,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
    input_entities: HashMap<String, gpui::Entity<NativeTextInput>>,
}

#[cfg(feature = "real-gpui")]
impl gpui::Render for ElixirRoot {
    fn render(
        &mut self,
        _window: &mut gpui::Window,
        cx: &mut gpui::Context<Self>,
    ) -> impl gpui::IntoElement {
        let tree = self
            .window_state
            .tree
            .lock()
            .map(|tree| tree.clone())
            .unwrap_or_else(|_| ElementNode::empty_root());
        tree.render(
            self.runtime.clone(),
            self.window_id,
            &mut self.input_entities,
            cx,
        )
    }
}

#[cfg(feature = "real-gpui")]
#[derive(Clone, Debug)]
enum ElementNode {
    Div {
        tag: GeneratedElementTag,
        style: StyleAttrs,
        children: Vec<ElementNode>,
        click: Option<String>,
    },
    Input {
        style: StyleAttrs,
        value: String,
        placeholder: Option<String>,
        change: Option<String>,
        keydown: Option<String>,
        keyup: Option<String>,
    },
    Image(ImageData),
    Text(String),
}

#[cfg(feature = "real-gpui")]
impl ElementNode {
    fn empty_root() -> Self {
        Self::Div {
            tag: GeneratedElementTag::Div,
            style: StyleAttrs::default(),
            children: Vec::new(),
            click: None,
        }
    }

    fn render(
        self,
        runtime: ResourceArc<RuntimeResource>,
        window_id: u64,
        input_entities: &mut HashMap<String, gpui::Entity<NativeTextInput>>,
        cx: &mut gpui::Context<ElixirRoot>,
    ) -> gpui::AnyElement {
        render_generated_element_node(self, runtime, window_id, input_entities, cx)
    }
}

#[cfg(feature = "real-gpui")]
fn render_generated_text_primitive(text: String) -> gpui::AnyElement {
    use gpui::IntoElement;
    text.into_any_element()
}

#[cfg(feature = "real-gpui")]
fn render_generated_image_primitive(
    raster: ImageData,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    match raster {
        ImageData::Raster(raster) => raster.render(),
        ImageData::Ref(resource_id) => {
            if let Some(raster) = runtime
                .resources
                .lock()
                .ok()
                .and_then(|resources| resources.get(&resource_id).cloned())
            {
                raster.render()
            } else {
                let _ = push_event(
                    &runtime,
                    NativeEvent::MissingResource {
                        window_id,
                        id: resource_id,
                        resource_type: "raster".to_string(),
                    },
                );
                render_missing_resource_placeholder()
            }
        }
    }
}

#[cfg(feature = "real-gpui")]
fn render_missing_resource_placeholder() -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement, Styled};

    div()
        .flex()
        .items_center()
        .justify_center()
        .border(gpui::px(1.0))
        .border_color(gpui::rgb(0xcc3333))
        .bg(gpui::rgb(0x332222))
        .text_color(gpui::rgb(0xffaaaa))
        .p(gpui::px(8.0))
        .child("missing resource")
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
fn apply_generated_container_semantics(element: gpui::Div, tag: GeneratedElementTag) -> gpui::Div {
    use gpui::Styled;

    match tag {
        GeneratedElementTag::Button => element
            .cursor(gpui::CursorStyle::PointingHand)
            .rounded(gpui::px(6.0))
            .px(gpui::px(10.0))
            .py(gpui::px(6.0)),
        GeneratedElementTag::Scroll => element,
        GeneratedElementTag::List => element.flex().flex_col().gap(gpui::px(4.0)),
        GeneratedElementTag::Item => element.p(gpui::px(4.0)),
        GeneratedElementTag::Span => element,
        _ => element,
    }
}

#[cfg(feature = "real-gpui")]
fn render_generated_input_primitive(
    style: StyleAttrs,
    value: String,
    placeholder: Option<String>,
    change: Option<String>,
    keydown: Option<String>,
    keyup: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
    input_entities: &mut HashMap<String, gpui::Entity<NativeTextInput>>,
    cx: &mut gpui::Context<ElixirRoot>,
) -> gpui::AnyElement {
    use gpui::{div, AppContext, ParentElement};

    let input_id = format!(
        "gpui-elixir-input-{window_id}-{}",
        change.clone().unwrap_or_default()
    );
    let input = if let Some(input) = input_entities.get(&input_id).cloned() {
        cx.update_entity(&input, |input, _cx| {
            input.update_props(value.clone(), placeholder.clone(), change.clone());
        });
        input
    } else {
        let input = cx.new(|cx| {
            NativeTextInput::new(
                input_id.clone(),
                runtime.clone(),
                window_id,
                value.clone(),
                placeholder.clone(),
                change.clone(),
                cx,
            )
        });
        input_entities.insert(input_id.clone(), input.clone());
        input
    };

    let element = apply_generated_render_styles(div(), style).child(input);
    apply_generated_input_events(element, value, change, keydown, keyup, runtime, window_id)
}

#[cfg(feature = "real-gpui")]
fn render_generated_container_primitive(
    tag: GeneratedElementTag,
    style: StyleAttrs,
    children: Vec<ElementNode>,
    click: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
    input_entities: &mut HashMap<String, gpui::Entity<NativeTextInput>>,
    cx: &mut gpui::Context<ElixirRoot>,
) -> gpui::AnyElement {
    use gpui::{div, InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};

    let mut element = apply_generated_render_styles(div(), style);
    element = apply_generated_container_semantics(element, tag);

    for child in children {
        element = element.child(child.render(runtime.clone(), window_id, input_entities, cx));
    }

    if tag == GeneratedElementTag::Scroll {
        let scroll_id = format!("gpui-elixir-scroll-{window_id}");
        let element = element.id(scroll_id).overflow_y_scroll();

        if let Some(event) = click {
            let runtime_for_click = runtime.clone();
            element
                .on_click(move |_event, _window, _cx| {
                    let _ = push_event(
                        &runtime_for_click,
                        NativeEvent::Click {
                            window_id,
                            event: event.clone(),
                        },
                    );
                })
                .into_any_element()
        } else {
            element.into_any_element()
        }
    } else {
        apply_generated_click_event(element, click, runtime, window_id)
    }
}

#[cfg(feature = "real-gpui")]
fn run_gpui_window(
    title: String,
    window_id: u64,
    window_state: SharedWindow,
    runtime: ResourceArc<RuntimeResource>,
) {
    use gpui::{px, size, App, AppContext, Bounds, WindowBounds, WindowOptions};

    gpui_platform::application().run(move |cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(500.0), px(500.0)), cx);
        let window_state_for_view = window_state.clone();
        let runtime_for_view = runtime.clone();

        let _ = cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |window, cx| {
                window.set_window_title(&title);
                cx.new(|cx| {
                    let (refresh_tx, mut refresh_rx) = mpsc::unbounded();
                    window_state_for_view.install_refresh_sender(refresh_tx);

                    cx.spawn(async move |root, cx| {
                        while refresh_rx.next().await.is_some() {
                            if root
                                .update_in(cx, |_root, window, cx| {
                                    cx.notify();
                                    window.refresh();
                                })
                                .is_err()
                            {
                                break;
                            }
                        }
                    })
                    .detach();

                    ElixirRoot {
                        window_state: window_state_for_view.clone(),
                        runtime: runtime_for_view.clone(),
                        window_id,
                        input_entities: HashMap::new(),
                    }
                })
            },
        );

        cx.activate(true);
    });
}

rustler::init!("Elixir.GPUI.Native");
