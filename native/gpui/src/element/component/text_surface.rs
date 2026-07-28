#[cfg(feature = "components")]
use crate::element::component::apply_component_styles;
#[cfg(feature = "components")]
use crate::{
    byte_range_to_selection, next_native_transaction_id, push_event, selection_to_byte_range,
    NativeEvent,
};
use crate::{gpui, ElementRenderContext, TextSurfaceNode};

#[cfg(feature = "real-gpui")]
impl std::fmt::Debug for TextSurfaceNode {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("TextSurfaceNode")
            .field("buffer", &"TextBufferResource")
            .field("id", &self.id)
            .field("focus_request", &self.focus_request)
            .field("disabled", &self.disabled)
            .field("soft_wrap", &self.soft_wrap)
            .field("show_whitespaces", &self.show_whitespaces)
            .field("tab_size", &self.tab_size)
            .field("hard_tabs", &self.hard_tabs)
            .field("transaction", &self.transaction)
            .field("selection_change", &self.selection_change)
            .finish_non_exhaustive()
    }
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct SelectionSync {
    state: gpui::Entity<gpui_component::input::InputState>,
    buffer: rustler::ResourceArc<crate::TextBufferResource>,
    runtime: crate::SharedRuntime,
    window_id: u64,
    event_revision: std::sync::Arc<std::sync::atomic::AtomicU64>,
    selection_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
}

#[cfg(feature = "components")]
impl SelectionSync {
    fn run(&self, cx: &mut gpui::App) {
        let state = self.state.read(cx);
        let text = state.value().to_string();
        let Ok(selection) = byte_range_to_selection(&text, state.selected_range()) else {
            return;
        };
        let Ok(snapshot) = self.buffer.snapshot() else {
            return;
        };
        if snapshot.selections == [selection.clone()] {
            return;
        }
        let revision = match self
            .buffer
            .update_selection_from_surface(snapshot.revision, selection.clone())
        {
            Ok(revision) => revision,
            Err(crate::TextBufferError::NoChange) => return,
            Err(_error) => return,
        };
        self.event_revision
            .store(revision, std::sync::atomic::Ordering::Release);

        if let Some(event) = self
            .selection_event
            .lock()
            .ok()
            .and_then(|event| event.clone())
        {
            let _ = push_event(
                &self.runtime,
                NativeEvent::Selection {
                    window_id: self.window_id,
                    event,
                    selections: vec![selection],
                    revision,
                },
            );
        }
    }
}

#[cfg(feature = "components")]
pub(crate) struct ComponentTextSurface {
    pub(crate) state: gpui::Entity<gpui_component::input::InputState>,
    pub(crate) revision: u64,
    pub(crate) event_revision: std::sync::Arc<std::sync::atomic::AtomicU64>,
    pub(crate) transaction_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
    pub(crate) selection_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
    pub(crate) focus_request: u64,
    pub(crate) text: String,
    pub(crate) selected_range: std::ops::Range<usize>,
    pub(crate) _subscription: gpui::Subscription,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    _element_id: usize,
    node: TextSurfaceNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{AppContext, Focusable, InteractiveElement, IntoElement, ParentElement, Styled};
    use gpui_component::input::{Input, InputEvent, InputState, TabSize};

    if context.components.text_surface_mut(&node.id).is_none() {
        let snapshot = match node.buffer.snapshot() {
            Ok(snapshot) => snapshot,
            Err(_error) => return error_placeholder("text buffer unavailable"),
        };
        let surface_id = node.id.clone();
        let event_surface_id = surface_id.clone();
        let state = context.cx.new(|cx| {
            InputState::new(context.window, cx)
                .multi_line(true)
                .soft_wrap(node.soft_wrap)
                .show_whitespaces(node.show_whitespaces)
                .tab_size(TabSize {
                    tab_size: node.tab_size as usize,
                    hard_tabs: node.hard_tabs,
                })
                .default_value(snapshot.text.clone())
        });
        let transaction_event =
            std::sync::Arc::new(std::sync::Mutex::new(node.transaction.clone()));
        let selection_event =
            std::sync::Arc::new(std::sync::Mutex::new(node.selection_change.clone()));
        let runtime = context.runtime.clone();
        let window_id = context.window_id;
        let event_transaction = transaction_event.clone();
        let event_selection = selection_event.clone();
        let buffer = node.buffer.clone();
        let event_buffer = buffer.clone();
        let revision = snapshot.revision;
        let event_revision =
            std::sync::Arc::new(std::sync::atomic::AtomicU64::new(snapshot.revision));
        let subscription_revision = event_revision.clone();
        let selected_range = snapshot
            .selections
            .iter()
            .find(|selection| selection.primary)
            .and_then(|selection| selection_to_byte_range(&snapshot.text, selection).ok())
            .unwrap_or(0..0);
        state.update(context.cx, |state, cx| {
            state.set_selected_range(selected_range.clone(), cx)
        });
        let subscription = context.cx.subscribe_in(
            &state,
            context.window,
            move |_root, state, event: &InputEvent, _window, cx| {
                if !matches!(event, InputEvent::Change) {
                    return;
                }
                let state = state.read(cx);
                let text = state.value().to_string();
                let selection = match byte_range_to_selection(&text, state.selected_range()) {
                    Ok(selection) => selection,
                    Err(_error) => return,
                };
                let current_revision =
                    subscription_revision.load(std::sync::atomic::Ordering::Acquire);
                let transaction_id = next_native_transaction_id(&event_surface_id);
                let Ok((transaction, revision)) = event_buffer.replace_from_surface(
                    current_revision,
                    transaction_id,
                    text,
                    selection.clone(),
                ) else {
                    return;
                };
                subscription_revision.store(revision, std::sync::atomic::Ordering::Release);
                if let Some(event) = event_transaction
                    .lock()
                    .ok()
                    .and_then(|event| event.clone())
                {
                    let _ = push_event(
                        &runtime,
                        NativeEvent::Transaction {
                            window_id,
                            event,
                            transaction,
                            revision,
                        },
                    );
                }
                if let Some(event) = event_selection.lock().ok().and_then(|event| event.clone()) {
                    let _ = push_event(
                        &runtime,
                        NativeEvent::Selection {
                            window_id,
                            event,
                            selections: vec![selection],
                            revision,
                        },
                    );
                }
            },
        );
        context.components.insert_text_surface(
            &surface_id,
            ComponentTextSurface {
                state,
                revision,
                event_revision,
                transaction_event,
                selection_event,
                focus_request: 0,
                text: snapshot.text,
                selected_range,
                _subscription: subscription,
            },
        );
    }

    let surface_id = node.id.clone();
    let Some(surface) = context.components.text_surface_mut(&surface_id) else {
        return error_placeholder("text surface state unavailable");
    };
    if let Ok(mut event) = surface.transaction_event.lock() {
        *event = node.transaction.clone();
    }
    if let Ok(mut event) = surface.selection_event.lock() {
        *event = node.selection_change.clone();
    }

    let native_text = surface.state.read(context.cx).value().to_string();
    if let Ok(revision) = node.buffer.revision() {
        if revision > surface.revision && native_text == surface.text {
            surface.revision = revision;
            surface
                .event_revision
                .store(revision, std::sync::atomic::Ordering::Release);
        }
    }

    if let Ok(snapshot) = node.buffer.snapshot() {
        if snapshot.revision != surface.revision {
            let snapshot_range = snapshot
                .selections
                .iter()
                .find(|selection| selection.primary)
                .and_then(|selection| selection_to_byte_range(&snapshot.text, selection).ok())
                .unwrap_or(0..0);
            let is_local_state = native_text == snapshot.text;
            surface.revision = snapshot.revision;
            surface
                .event_revision
                .store(snapshot.revision, std::sync::atomic::Ordering::Release);
            surface.text = snapshot.text.clone();
            surface.selected_range = snapshot_range.clone();
            if !is_local_state {
                surface.state.update(context.cx, |state, cx| {
                    state.set_value(snapshot.text, context.window, cx);
                    state.set_selected_range(snapshot_range, cx);
                });
            }
        }
    }

    let current_range = surface.state.read(context.cx).selected_range();
    if current_range != surface.selected_range {
        if let Ok(selection) = byte_range_to_selection(&surface.text, current_range.clone()) {
            if let Ok(revision) = node
                .buffer
                .update_selection_from_surface(surface.revision, selection.clone())
            {
                surface.revision = revision;
                surface
                    .event_revision
                    .store(revision, std::sync::atomic::Ordering::Release);
                surface.selected_range = current_range;
                if let Some(event) = node.selection_change.clone() {
                    let _ = push_event(
                        &context.runtime,
                        NativeEvent::Selection {
                            window_id: context.window_id,
                            event,
                            selections: vec![selection],
                            revision,
                        },
                    );
                }
            }
        }
    }

    surface.state.update(context.cx, |state, cx| {
        state.set_soft_wrap(node.soft_wrap, context.window, cx);
        state.set_show_whitespaces(node.show_whitespaces, context.window, cx);
    });
    let request_focus = surface.focus_request != node.focus_request;
    surface.focus_request = node.focus_request;
    let focus = surface.state.focus_handle(context.cx);
    if request_focus && node.focus_request > 0 {
        let focus = focus.clone();
        context
            .window
            .defer(context.cx, move |window, cx| focus.focus(window, cx));
    }

    let selection_sync = SelectionSync {
        state: surface.state.clone(),
        buffer: node.buffer.clone(),
        runtime: context.runtime.clone(),
        window_id: context.window_id,
        event_revision: surface.event_revision.clone(),
        selection_event: surface.selection_event.clone(),
    };
    let mouse_selection_sync = selection_sync.clone();

    let input = Input::new(&surface.state)
        .disabled(node.disabled)
        .appearance(false)
        .bordered(false)
        .focus_bordered(false)
        .h_full();
    gpui::div()
        .id(format!("text-surface-{surface_id}"))
        .track_focus(&focus.tab_stop(!node.disabled))
        .on_key_up(move |_event, _window, cx| selection_sync.run(cx))
        .on_mouse_up(gpui::MouseButton::Left, move |_event, _window, cx| {
            mouse_selection_sync.run(cx)
        })
        .size_full()
        .child(apply_component_styles(input, node.style))
        .into_any_element()
}

#[cfg(feature = "components")]
fn error_placeholder(message: &str) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement, Styled};
    gpui::div()
        .p(gpui::px(8.))
        .child(message.to_string())
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    _element_id: usize,
    node: TextSurfaceNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};
    let text = node
        .buffer
        .snapshot()
        .map(|snapshot| snapshot.text)
        .unwrap_or_default();
    super::super::apply_generated_render_styles(gpui::div(), node.style)
        .child(text)
        .into_any_element()
}
