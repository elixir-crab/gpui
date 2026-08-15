#[cfg(feature = "components")]
use crate::element::component::apply_component_styles;
#[cfg(feature = "components")]
use crate::{
    byte_range_to_selection, next_native_transaction_id, position_to_byte_offset, push_event,
    selection_to_byte_range, NativeEvent,
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
            .field("auto_grow", &self.auto_grow)
            .field("min_lines", &self.min_lines)
            .field("max_lines", &self.max_lines)
            .field("submit_policy", &self.submit_policy)
            .field("show_whitespaces", &self.show_whitespaces)
            .field("tab_size", &self.tab_size)
            .field("hard_tabs", &self.hard_tabs)
            .field("submit", &self.submit)
            .field("transaction", &self.transaction)
            .field("selection_change", &self.selection_change)
            .field("viewport_change", &self.viewport_change)
            .field("geometry_change", &self.geometry_change)
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
type ViewportKey = (usize, usize, i32, i32, i32);

#[cfg(feature = "components")]
type RangeGeometryKey = (u64, u64, u64, u64, i32, i32, i32, i32);

#[cfg(feature = "components")]
pub(crate) struct ComponentTextSurface {
    pub(crate) state: gpui::Entity<gpui_component::input::InputState>,
    pub(crate) revision: u64,
    pub(crate) event_revision: std::sync::Arc<std::sync::atomic::AtomicU64>,
    pub(crate) transaction_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
    pub(crate) submit_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
    pub(crate) selection_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
    pub(crate) viewport_event: Option<String>,
    pub(crate) geometry_event: Option<String>,
    pub(crate) range_geometry_event: Option<String>,
    pub(crate) hit_test_event: Option<String>,
    pub(crate) focus_event: Option<String>,
    pub(crate) blur_event: Option<String>,
    pub(crate) auto_grow: bool,
    pub(crate) min_lines: u64,
    pub(crate) max_lines: u64,
    pub(crate) submit_policy: String,
    pub(crate) scroll_request: u64,
    pub(crate) last_viewport: Option<ViewportKey>,
    pub(crate) last_caret: Option<(u64, u64, i32, i32, i32, i32)>,
    pub(crate) last_range_geometry: Option<Vec<RangeGeometryKey>>,
    pub(crate) focus_request: u64,
    pub(crate) text: String,
    pub(crate) selected_range: std::ops::Range<usize>,
    pub(crate) style_runs: gpui_component::input::TextDecorationCollection,
    pub(crate) _subscription: gpui::Subscription,
}

#[cfg(feature = "components")]
impl ComponentTextSurface {
    pub(crate) fn state_focus_handle(&self, cx: &gpui::App) -> gpui::FocusHandle {
        use gpui::Focusable;

        self.state.focus_handle(cx)
    }

    pub(crate) fn update_focus_events(&mut self, focus: Option<String>, blur: Option<String>) {
        self.focus_event = focus;
        self.blur_event = blur;
    }
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
            if node.auto_grow {
                InputState::new(context.window, cx)
                    .auto_grow(node.min_lines as usize, node.max_lines as usize)
                    .soft_wrap(node.soft_wrap)
                    .submit_on_enter(node.submit_policy == "submit")
                    .show_whitespaces(node.show_whitespaces)
                    .tab_size(TabSize {
                        tab_size: node.tab_size as usize,
                        hard_tabs: node.hard_tabs,
                    })
                    .default_value(snapshot.text.clone())
            } else {
                InputState::new(context.window, cx)
                    .multi_line(true)
                    .soft_wrap(node.soft_wrap)
                    .submit_on_enter(node.submit_policy == "submit")
                    .show_whitespaces(node.show_whitespaces)
                    .tab_size(TabSize {
                        tab_size: node.tab_size as usize,
                        hard_tabs: node.hard_tabs,
                    })
                    .default_value(snapshot.text.clone())
            }
        });
        let transaction_event =
            std::sync::Arc::new(std::sync::Mutex::new(node.transaction.clone()));
        let submit_event = std::sync::Arc::new(std::sync::Mutex::new(node.submit.clone()));
        let selection_event =
            std::sync::Arc::new(std::sync::Mutex::new(node.selection_change.clone()));
        let runtime = context.runtime.clone();
        let window_id = context.window_id;
        let event_transaction = transaction_event.clone();
        let event_submit = submit_event.clone();
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
        let style_runs = state.update(context.cx, |state, cx| {
            state.create_decorations_collection(Vec::new(), cx)
        });
        let subscription = context.cx.subscribe_in(
            &state,
            context.window,
            move |_root, state, event: &InputEvent, _window, cx| match event {
                InputEvent::Change => {
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
                    if let Some(event) = event_selection.lock().ok().and_then(|event| event.clone())
                    {
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
                }
                InputEvent::PressEnter { shift: false, .. } => {
                    if let Some(event) = event_submit.lock().ok().and_then(|event| event.clone()) {
                        let value = event_buffer
                            .snapshot()
                            .map(|snapshot| snapshot.text)
                            .unwrap_or_default();
                        let _ = push_event(
                            &runtime,
                            NativeEvent::Input {
                                kind: crate::InputKind::Submit,
                                window_id,
                                event,
                                value: Some(crate::EventValue::String(value)),
                            },
                        );
                    }
                }
                InputEvent::PressEnter { .. } | InputEvent::Focus | InputEvent::Blur => {}
            },
        );
        context.components.insert_text_surface(
            &surface_id,
            ComponentTextSurface {
                state,
                revision,
                event_revision,
                transaction_event,
                submit_event,
                selection_event,
                viewport_event: node.viewport_change.clone(),
                geometry_event: node.geometry_change.clone(),
                range_geometry_event: node.range_geometry_change.clone(),
                hit_test_event: node.hit_test.clone(),
                focus_event: node.focus.clone(),
                blur_event: node.blur.clone(),
                auto_grow: node.auto_grow,
                min_lines: node.min_lines,
                max_lines: node.max_lines,
                submit_policy: node.submit_policy.clone(),
                scroll_request: 0,
                last_viewport: None,
                last_caret: None,
                last_range_geometry: None,
                focus_request: 0,
                text: snapshot.text,
                selected_range,
                style_runs,
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
    if let Ok(mut event) = surface.submit_event.lock() {
        *event = node.submit.clone();
    }
    if let Ok(mut event) = surface.selection_event.lock() {
        *event = node.selection_change.clone();
    }
    surface.viewport_event = node.viewport_change.clone();
    surface.geometry_event = node.geometry_change.clone();
    surface.range_geometry_event = node.range_geometry_change.clone();
    surface.hit_test_event = node.hit_test.clone();
    surface.update_focus_events(node.focus.clone(), node.blur.clone());
    surface.style_runs.set(
        shaping_decorations(&surface.text, &node.style_runs),
        context.cx,
    );

    let focus_handle = surface.state_focus_handle(context.cx);
    if node.focus.is_some() || node.blur.is_some() {
        let key = (context.window_id, surface_id.clone());
        if let Ok(mut bindings) = context.runtime.focus_bindings.lock() {
            bindings.insert(key.clone(), (node.focus.clone(), node.blur.clone()));
        }
        let install = context
            .runtime
            .focus_observers
            .lock()
            .map(|mut observers| observers.insert(key))
            .unwrap_or(false);
        if install {
            crate::element::install_focus_observers(
                focus_handle.clone(),
                surface_id.clone(),
                context.runtime.clone(),
                context.window_id,
                context.window,
                context.cx,
            );
        }
    }

    let mode_changed = surface.auto_grow != node.auto_grow
        || surface.min_lines != node.min_lines
        || surface.max_lines != node.max_lines
        || surface.submit_policy != node.submit_policy;
    if mode_changed {
        context.components.remove_text_surface(&surface_id);
        return render(_element_id, node, context);
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

    if surface.scroll_request != node.scroll_request {
        surface.scroll_request = node.scroll_request;
        if let Some(position) = &node.scroll_to {
            if let Ok(offset) = position_to_byte_offset(&surface.text, position) {
                surface.state.update(context.cx, |state, cx| {
                    state.set_selected_range(offset..offset, cx)
                });
            }
        }
    }

    emit_geometry_events(
        surface,
        &node.geometry_ranges,
        &context.runtime,
        context.window_id,
        context.cx,
    );

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

    let decoration_quads =
        decoration_quads(&surface.state, &surface.text, &node.decorations, context.cx);

    let selection_sync = SelectionSync {
        state: surface.state.clone(),
        buffer: node.buffer.clone(),
        runtime: context.runtime.clone(),
        window_id: context.window_id,
        event_revision: surface.event_revision.clone(),
        selection_event: surface.selection_event.clone(),
    };
    let mouse_selection_sync = selection_sync.clone();

    let hit_state = surface.state.clone();
    let hit_runtime = context.runtime.clone();
    let hit_event = surface.hit_test_event.clone();
    let hit_revision = surface.event_revision.clone();
    let hit_text = surface.text.clone();
    let hit_window_id = context.window_id;

    let input = Input::new(&surface.state)
        .disabled(node.disabled)
        .appearance(false)
        .bordered(false)
        .focus_bordered(false)
        .h_full();
    let projection_labels = projection_labels(
        &surface.state,
        &surface.text,
        &node.inline_projections,
        context.cx,
    );
    let block_labels = block_labels(
        &surface.state,
        &surface.text,
        &node.block_projections,
        context.cx,
    );

    let decorations = gpui::canvas(
        |_bounds, _window, _cx| {},
        move |_bounds, _prepaint, window, cx| {
            for (bounds, background, underline) in &decoration_quads {
                if let Some(color) = background {
                    window.paint_quad(gpui::fill(*bounds, gpui::rgb(*color)));
                }
                if let Some((color, kind)) = underline {
                    paint_underline(window, *bounds, *color, *kind);
                }
            }
            let text_style = window.text_style();
            for (bounds, text, color, background) in &block_labels {
                if let Some(background) = background {
                    window.paint_quad(gpui::fill(*bounds, gpui::rgb(*background)));
                }
                paint_projection_text(
                    window,
                    cx,
                    gpui::point(
                        bounds.origin.x + gpui::px(6.),
                        bounds.origin.y + gpui::px(3.),
                    ),
                    text,
                    *color,
                    &text_style,
                );
            }
            for (position, text, color) in &projection_labels {
                paint_projection_text(window, cx, *position, text, *color, &text_style);
            }
        },
    )
    .absolute()
    .inset_0();

    gpui::div()
        .relative()
        .id(format!("text-surface-{surface_id}"))
        .track_focus(&focus.tab_stop(!node.disabled))
        .on_key_up(move |_event, _window, cx| selection_sync.run(cx))
        .on_mouse_up(gpui::MouseButton::Left, move |_event, _window, cx| {
            mouse_selection_sync.run(cx);
            if let Some(event_name) = &hit_event {
                let selected = hit_state.read(cx).selected_range();
                if let Ok(position) = byte_range_to_selection(&hit_text, selected.end..selected.end)
                {
                    let _ = push_event(
                        &hit_runtime,
                        NativeEvent::HitTest {
                            window_id: hit_window_id,
                            event: event_name.clone(),
                            value: position.head,
                            revision: hit_revision.load(std::sync::atomic::Ordering::Acquire),
                        },
                    );
                }
            }
        })
        .size_full()
        .child(apply_component_styles(input, node.style))
        .child(decorations)
        .into_any_element()
}

#[cfg(feature = "components")]
fn shaping_decorations(
    text: &str,
    runs: &[crate::TextStyleRunNode],
) -> Vec<gpui_component::input::TextDecoration> {
    runs.iter()
        .take(512)
        .filter_map(|run| {
            let range = crate::text_buffer::range_to_byte_range(text, &run.range).ok()?;
            if range.is_empty() {
                return None;
            }
            let font_weight = run.font_weight.as_deref().and_then(|weight| match weight {
                "thin" => Some(gpui::FontWeight::THIN),
                "extra_light" => Some(gpui::FontWeight::EXTRA_LIGHT),
                "light" => Some(gpui::FontWeight::LIGHT),
                "normal" => Some(gpui::FontWeight::NORMAL),
                "medium" => Some(gpui::FontWeight::MEDIUM),
                "semibold" => Some(gpui::FontWeight::SEMIBOLD),
                "bold" => Some(gpui::FontWeight::BOLD),
                "extra_bold" => Some(gpui::FontWeight::EXTRA_BOLD),
                "black" => Some(gpui::FontWeight::BLACK),
                _ => None,
            });
            let font_style = run.font_style.as_deref().and_then(|style| match style {
                "normal" => Some(gpui::FontStyle::Normal),
                "italic" => Some(gpui::FontStyle::Italic),
                "oblique" => Some(gpui::FontStyle::Oblique),
                _ => None,
            });
            Some(gpui_component::input::TextDecoration::new(
                range,
                gpui::HighlightStyle {
                    color: run.color.map(|color| gpui::rgb(color).into()),
                    font_weight,
                    font_style,
                    ..Default::default()
                },
            ))
        })
        .collect()
}

#[cfg(feature = "components")]
fn paint_projection_text(
    window: &mut gpui::Window,
    cx: &mut gpui::App,
    position: gpui::Point<gpui::Pixels>,
    text: &str,
    color: u32,
    text_style: &gpui::TextStyle,
) {
    let run = gpui::TextRun {
        len: text.len(),
        font: text_style.font(),
        color: gpui::rgb(color).into(),
        background_color: None,
        underline: None,
        strikethrough: None,
    };
    let line = window.text_system().shape_line(
        text.to_string().into(),
        text_style.font_size.to_pixels(window.rem_size()),
        &[run],
        None,
    );
    let _ = line.paint(
        position,
        window.line_height(),
        gpui::TextAlign::Left,
        None,
        window,
        cx,
    );
}

#[cfg(feature = "components")]
fn block_labels(
    state: &gpui::Entity<gpui_component::input::InputState>,
    text: &str,
    projections: &[crate::TextBlockProjectionNode],
    cx: &gpui::App,
) -> Vec<(gpui::Bounds<gpui::Pixels>, String, u32, Option<u32>)> {
    let state = state.read(cx);
    projections
        .iter()
        .take(64)
        .filter_map(|projection| {
            let line = usize::try_from(projection.line).ok()?;
            let position = if projection.placement == "before" {
                crate::TextPosition {
                    line: projection.line,
                    utf16_offset: 0,
                }
            } else {
                let next_line = line.checked_add(1)?;
                crate::TextPosition {
                    line: next_line as u64,
                    utf16_offset: 0,
                }
            };
            let offset = position_to_byte_offset(text, &position).ok()?;
            let anchor = state.range_to_bounds(&(offset..offset))?;
            let height = gpui::px(projection.height as f32);
            let y = if projection.placement == "before" {
                anchor.origin.y - height
            } else {
                anchor.origin.y
            };
            let bounds = gpui::Bounds::new(
                gpui::point(anchor.origin.x, y),
                gpui::size(gpui::px(360.), height),
            );
            Some((
                bounds,
                projection.text.clone(),
                projection.color,
                projection.background,
            ))
        })
        .collect()
}

#[cfg(feature = "components")]
fn projection_labels(
    state: &gpui::Entity<gpui_component::input::InputState>,
    text: &str,
    projections: &[crate::TextInlineProjectionNode],
    cx: &gpui::App,
) -> Vec<(gpui::Point<gpui::Pixels>, String, u32)> {
    let state = state.read(cx);
    projections
        .iter()
        .take(128)
        .filter_map(|projection| {
            let offset = position_to_byte_offset(text, &projection.position).ok()?;
            let bounds = state.range_to_bounds(&(offset..offset))?;
            Some((bounds.origin, projection.text.clone(), projection.color))
        })
        .collect()
}

#[cfg(feature = "components")]
type DecorationQuad = (
    gpui::Bounds<gpui::Pixels>,
    Option<u32>,
    Option<(u32, UnderlineKind)>,
);

#[cfg(feature = "components")]
#[derive(Clone, Copy)]
enum UnderlineKind {
    Solid,
    Dashed,
    Wavy,
}

#[cfg(feature = "components")]
fn decoration_quads(
    state: &gpui::Entity<gpui_component::input::InputState>,
    text: &str,
    decorations: &[crate::TextDecorationNode],
    cx: &gpui::App,
) -> Vec<DecorationQuad> {
    let state = state.read(cx);
    decorations
        .iter()
        .take(256)
        .filter_map(|decoration| {
            let range = crate::text_buffer::range_to_byte_range(text, &decoration.range).ok()?;
            let bounds = state.range_to_bounds(&range)?;
            let underline = decoration.underline.map(|color| {
                let kind = match decoration.underline_style.as_str() {
                    "dashed" => UnderlineKind::Dashed,
                    "wavy" => UnderlineKind::Wavy,
                    _ => UnderlineKind::Solid,
                };
                (color, kind)
            });
            Some((bounds, decoration.background, underline))
        })
        .collect()
}

#[cfg(feature = "components")]
fn paint_underline(
    window: &mut gpui::Window,
    bounds: gpui::Bounds<gpui::Pixels>,
    color: u32,
    kind: UnderlineKind,
) {
    match kind {
        UnderlineKind::Solid => {
            let underline = gpui::Bounds::new(
                gpui::point(bounds.origin.x, bounds.bottom() - gpui::px(2.)),
                gpui::size(bounds.size.width, gpui::px(2.)),
            );
            window.paint_quad(gpui::fill(underline, gpui::rgb(color)));
        }
        UnderlineKind::Dashed => {
            let mut x = bounds.origin.x;
            while x < bounds.right() {
                let width = (bounds.right() - x).min(gpui::px(5.));
                let dash = gpui::Bounds::new(
                    gpui::point(x, bounds.bottom() - gpui::px(2.)),
                    gpui::size(width, gpui::px(2.)),
                );
                window.paint_quad(gpui::fill(dash, gpui::rgb(color)));
                x += gpui::px(8.);
            }
        }
        UnderlineKind::Wavy => {
            let mut builder = gpui::PathBuilder::stroke(gpui::px(1.5));
            let mut x = bounds.origin.x;
            let baseline = bounds.bottom() - gpui::px(2.);
            builder.move_to(gpui::point(x, baseline));
            let mut up = true;
            while x < bounds.right() {
                x = (x + gpui::px(3.)).min(bounds.right());
                let y = if up {
                    baseline - gpui::px(2.)
                } else {
                    baseline
                };
                builder.line_to(gpui::point(x, y));
                up = !up;
            }
            if let Ok(path) = builder.build() {
                window.paint_path(path, gpui::rgb(color));
            }
        }
    }
}

#[cfg(feature = "components")]
fn emit_geometry_events(
    surface: &mut ComponentTextSurface,
    requested_ranges: &[crate::TextRange],
    runtime: &crate::SharedRuntime,
    window_id: u64,
    cx: &gpui::App,
) {
    use crate::{TextCaretGeometry, TextViewportGeometry};

    let state = surface.state.read(cx);
    let revision = surface
        .event_revision
        .load(std::sync::atomic::Ordering::Acquire);

    if let (Some(event), Some(range)) = (&surface.viewport_event, state.visible_row_range()) {
        let scroll = state.scroll_offset();
        let line_height = state.line_height().unwrap_or(gpui::px(0.));
        let key = (
            range.start,
            range.end,
            f32::from(scroll.x).round() as i32,
            f32::from(scroll.y).round() as i32,
            f32::from(line_height).round() as i32,
        );
        if surface.last_viewport != Some(key) {
            surface.last_viewport = Some(key);
            let _ = push_event(
                runtime,
                NativeEvent::Viewport {
                    window_id,
                    event: event.clone(),
                    value: TextViewportGeometry {
                        first_visible_row: range.start as u64,
                        last_visible_row: range.end.saturating_sub(1) as u64,
                        scroll_x: f32::from(scroll.x) as f64,
                        scroll_y: f32::from(scroll.y) as f64,
                        line_height: f32::from(line_height) as f64,
                    },
                    revision,
                },
            );
        }
    }

    if let Some(event) = &surface.geometry_event {
        let selected = state.selected_range();
        let caret = selected.end;
        if let Some(bounds) = state.range_to_bounds(&(caret..caret)) {
            if let Ok(selection) = byte_range_to_selection(&surface.text, caret..caret) {
                let key = (
                    selection.head.line,
                    selection.head.utf16_offset,
                    f32::from(bounds.origin.x).round() as i32,
                    f32::from(bounds.origin.y).round() as i32,
                    f32::from(bounds.size.width).round() as i32,
                    f32::from(bounds.size.height).round() as i32,
                );
                if surface.last_caret != Some(key) {
                    surface.last_caret = Some(key);
                    let _ = push_event(
                        runtime,
                        NativeEvent::Geometry {
                            window_id,
                            event: event.clone(),
                            value: TextCaretGeometry {
                                line: selection.head.line,
                                utf16_offset: selection.head.utf16_offset,
                                x: f32::from(bounds.origin.x) as f64,
                                y: f32::from(bounds.origin.y) as f64,
                                width: f32::from(bounds.size.width) as f64,
                                height: f32::from(bounds.size.height) as f64,
                            },
                            revision,
                        },
                    );
                }
            }
        }
    }

    if let Some(event) = &surface.range_geometry_event {
        let mut key = Vec::new();
        let mut geometries = Vec::new();
        for range in requested_ranges.iter().take(64) {
            let Ok(byte_range) = crate::text_buffer::range_to_byte_range(&surface.text, range)
            else {
                continue;
            };
            let Some(bounds) = state.range_to_bounds(&byte_range) else {
                continue;
            };
            let rectangles = split_range_bounds(bounds, state.line_height());
            for rectangle in &rectangles {
                key.push((
                    range.start.line,
                    range.start.utf16_offset,
                    range.end.line,
                    range.end.utf16_offset,
                    f32::from(rectangle.origin.x).round() as i32,
                    f32::from(rectangle.origin.y).round() as i32,
                    f32::from(rectangle.size.width).round() as i32,
                    f32::from(rectangle.size.height).round() as i32,
                ));
            }
            geometries.push(crate::TextRangeGeometry {
                range: range.clone(),
                rectangles: rectangles
                    .into_iter()
                    .map(|rectangle| crate::TextRectangle {
                        x: f32::from(rectangle.origin.x) as f64,
                        y: f32::from(rectangle.origin.y) as f64,
                        width: f32::from(rectangle.size.width) as f64,
                        height: f32::from(rectangle.size.height) as f64,
                    })
                    .collect(),
            });
        }
        if surface.last_range_geometry.as_ref() != Some(&key) {
            surface.last_range_geometry = Some(key);
            let _ = push_event(
                runtime,
                NativeEvent::RangeGeometry {
                    window_id,
                    event: event.clone(),
                    value: geometries,
                    revision,
                },
            );
        }
    }
}

#[cfg(feature = "components")]
fn split_range_bounds(
    bounds: gpui::Bounds<gpui::Pixels>,
    line_height: Option<gpui::Pixels>,
) -> Vec<gpui::Bounds<gpui::Pixels>> {
    let Some(line_height) = line_height.filter(|height| *height > gpui::px(0.)) else {
        return vec![bounds];
    };
    let mut rectangles = Vec::new();
    let mut y = bounds.origin.y;
    let bottom = bounds.bottom();
    while y < bottom && rectangles.len() < 256 {
        let height = (bottom - y).min(line_height);
        rectangles.push(gpui::Bounds::new(
            gpui::point(bounds.origin.x, y),
            gpui::size(bounds.size.width, height),
        ));
        y += line_height;
    }
    rectangles
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::{shaping_decorations, split_range_bounds};
    use crate::gpui::{bounds, point, px, size, FontStyle, FontWeight};
    use crate::{TextPosition, TextRange, TextStyleRunNode};

    fn position(line: u64, utf16_offset: u64) -> TextPosition {
        TextPosition { line, utf16_offset }
    }

    #[test]
    fn style_runs_convert_utf16_ranges_into_native_shaping_decorations() {
        let text = "a💝b\ncombining é";
        let runs = vec![TextStyleRunNode {
            range: TextRange {
                start: position(0, 1),
                end: position(0, 3),
            },
            color: Some(0xF97316),
            font_weight: Some("semibold".to_string()),
            font_style: Some("italic".to_string()),
        }];

        let decorations = shaping_decorations(text, &runs);
        assert_eq!(decorations.len(), 1);
        assert_eq!(decorations[0].range, 1..5);
        assert_eq!(decorations[0].style.font_weight, Some(FontWeight::SEMIBOLD));
        assert_eq!(decorations[0].style.font_style, Some(FontStyle::Italic));
        assert_eq!(
            decorations[0].style.color,
            Some(crate::gpui::rgb(0xF97316).into())
        );
    }

    #[test]
    fn style_runs_reject_surrogate_splits_and_empty_ranges() {
        let text = "a💝b";
        let runs = vec![
            TextStyleRunNode {
                range: TextRange {
                    start: position(0, 2),
                    end: position(0, 3),
                },
                color: Some(0xFFFFFF),
                font_weight: None,
                font_style: None,
            },
            TextStyleRunNode {
                range: TextRange {
                    start: position(0, 0),
                    end: position(0, 0),
                },
                color: Some(0xFFFFFF),
                font_weight: None,
                font_style: None,
            },
        ];

        assert!(shaping_decorations(text, &runs).is_empty());
    }

    #[test]
    fn wrapped_range_bounds_are_bounded_per_visual_row() {
        let bounds = bounds(point(px(10.), px(20.)), size(px(100.), px(50.)));
        let rectangles = split_range_bounds(bounds, Some(px(20.)));

        assert_eq!(rectangles.len(), 3);
        assert_eq!(rectangles[0].origin.y, px(20.));
        assert_eq!(rectangles[1].origin.y, px(40.));
        assert_eq!(rectangles[2].origin.y, px(60.));
        assert_eq!(rectangles[2].size.height, px(10.));
    }
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
fn acknowledge_geometry_contract(node: &TextSurfaceNode) {
    let _ = (
        &node.geometry_ranges,
        &node.range_geometry_change,
        node.scroll_request,
        &node.scroll_to,
        &node.hit_test,
        &node.decorations,
        &node.style_runs,
        &node.inline_projections,
        &node.block_projections,
        &node.focus,
        &node.blur,
    );
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    _element_id: usize,
    node: TextSurfaceNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};
    acknowledge_geometry_contract(&node);
    let text = node
        .buffer
        .snapshot()
        .map(|snapshot| snapshot.text)
        .unwrap_or_default();
    super::super::apply_generated_render_styles(gpui::div(), node.style)
        .child(text)
        .into_any_element()
}
