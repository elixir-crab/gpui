use rustler::{Atom, Encoder, Env, NifResult, ResourceArc, Term};
use std::sync::Mutex;

#[cfg(feature = "real-gpui")]
use std::sync::atomic::{AtomicBool, Ordering};

#[cfg(feature = "real-gpui")]
static GPUI_STARTED: AtomicBool = AtomicBool::new(false);

include!("generated_atoms.rs");
include!("generated_nifs.rs");

pub struct RuntimeResource {
    events: Mutex<Vec<String>>,
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
    push_event(&runtime, format!("window_open_requested:{title}"))?;
    Ok((atoms::ok(), title).encode(env))
}

#[cfg(feature = "real-gpui")]
fn open_window_impl<'a>(
    env: Env<'a>,
    runtime: ResourceArc<RuntimeResource>,
    window: Term<'a>,
) -> NifResult<Term<'a>> {
    let title = window_title(env, window)?;

    if GPUI_STARTED.swap(true, Ordering::SeqCst) {
        push_event(&runtime, "window_open_rejected:already_started".to_string())?;
        return Ok((atoms::error(), "gpui_already_started").encode(env));
    }

    let event_title = title.clone();
    std::thread::spawn(move || run_gpui_window(title));
    push_event(&runtime, format!("window_open_requested:{event_title}"))?;

    Ok((atoms::ok(), event_title).encode(env))
}

fn drain_events_impl<'a>(env: Env<'a>, runtime: ResourceArc<RuntimeResource>) -> NifResult<Term<'a>> {
    let mut events = runtime
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?;
    let drained = std::mem::take(&mut *events);
    Ok((atoms::ok(), drained).encode(env))
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

fn push_event(runtime: &ResourceArc<RuntimeResource>, event: String) -> NifResult<()> {
    runtime
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .push(event);

    Ok(())
}

#[cfg(feature = "real-gpui")]
fn run_gpui_window(title: String) {
    use gpui::prelude::*;
    use gpui::{div, px, rgb, size, App, Bounds, Context, Render, Window, WindowBounds, WindowOptions};

    struct HelloWorld {
        title: String,
    }

    impl Render for HelloWorld {
        fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl gpui::IntoElement {
            div()
                .flex()
                .flex_col()
                .gap_3()
                .bg(rgb(0x505050))
                .size(px(500.0))
                .justify_center()
                .items_center()
                .text_xl()
                .text_color(rgb(0xffffff))
                .child(format!("Hello from Elixir/OTP via {}", self.title))
        }
    }

    gpui_platform::application().run(move |cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(500.0), px(500.0)), cx);
        let title_for_view = title.clone();

        let _ = cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |window, cx| {
                window.set_window_title(&title);
                cx.new(|_| HelloWorld {
                    title: title_for_view.clone(),
                })
            },
        );

        cx.activate(true);
    });
}

rustler::init!("Elixir.GPUI.Native");
