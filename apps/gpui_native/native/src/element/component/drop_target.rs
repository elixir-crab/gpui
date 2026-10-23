use crate::{gpui, DropTargetComponentNode, ElementRenderContext};

#[cfg(feature = "components")]
use super::drag_source::DraggedValue;
#[cfg(feature = "components")]
use std::sync::atomic::{AtomicU64, Ordering};
#[cfg(feature = "components")]
use std::sync::{Arc, Mutex};

#[cfg(feature = "components")]
static NEXT_TRANSFER_SESSION_ID: AtomicU64 = AtomicU64::new(1);

#[cfg(feature = "components")]
pub(crate) struct ComponentDropTarget {
    id: String,
    session: Arc<Mutex<Option<TransferSession>>>,
    runtime: crate::SharedRuntime,
    window_id: u64,
    leave_event: Option<String>,
}

#[cfg(feature = "components")]
impl ComponentDropTarget {
    fn new(node: &DropTargetComponentNode, context: &ElementRenderContext<'_, '_>) -> Self {
        Self {
            id: node.id.clone(),
            session: Arc::new(Mutex::new(None)),
            runtime: context.runtime.clone(),
            window_id: context.window_id,
            leave_event: node.drag_leave.clone(),
        }
    }

    fn update(&mut self, node: &DropTargetComponentNode) {
        self.leave_event.clone_from(&node.drag_leave);
    }

    pub(crate) fn terminate_removed(&self) {
        let Ok(mut session) = self.session.lock() else {
            return;
        };
        if let (Some(active), Some(event)) = (session.take(), self.leave_event.as_deref()) {
            emit_transfer(
                &self.runtime,
                crate::InputKind::DragLeave,
                self.window_id,
                event,
                TransferEmission {
                    target_id: &self.id,
                    session_id: active.session_id,
                    position: active.last_position,
                    payload: None,
                },
            );
        }
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: DropTargetComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{InteractiveElement, IntoElement, ParentElement};

    if context.components.drop_target_mut(&node.id).is_none() {
        let component = ComponentDropTarget::new(&node, context);
        context.components.insert_drop_target(&node.id, component);
    }
    let component = context
        .components
        .drop_target_mut(&node.id)
        .expect("drop target must exist after insertion");
    component.update(&node);

    let target = TargetEvents {
        session: component.session.clone(),
        runtime: context.runtime.clone(),
        window_id: context.window_id,
        target_id: node.id.clone(),
        enter: node.drag_enter.clone(),
        moved: node.drag_move.clone(),
        leave: node.drag_leave.clone(),
        drop: node.drop.clone(),
    };
    let accepts_values = node.accepts.as_deref() == Some("values");

    let children = node
        .children
        .into_iter()
        .map(|child| child.render(context))
        .collect::<Vec<_>>();
    let exit_target = target.clone();

    let element = apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .children(children)
        .child(gpui::canvas(
            |_bounds, _window, _cx| (),
            move |_bounds, (), window, _cx| {
                let target = exit_target.clone();
                window.on_mouse_event(
                    move |file_event: &gpui::FileDropEvent, phase, _window, _cx| {
                        if phase == gpui::DispatchPhase::Bubble
                            && matches!(file_event, gpui::FileDropEvent::Exited)
                        {
                            target.exited();
                        }
                    },
                );
                // A value drag ends with the mouse button. Once the release has
                // been dispatched, a drop here has taken the session; one still
                // open was released somewhere else.
                let target = exit_target.clone();
                window.on_mouse_event(move |event: &gpui::MouseUpEvent, phase, window, cx| {
                    if phase == gpui::DispatchPhase::Bubble {
                        let target = target.clone();
                        let position = event.position;
                        window.defer(cx, move |_window, _cx| target.released_elsewhere(position));
                    }
                });
            },
        ));

    let move_target = target.clone();
    let drop_target = target;

    if accepts_values {
        element
            .can_drop(|value, _window, _cx| value.is::<DraggedValue>())
            .on_drag_move::<DraggedValue>(move |event, _window, cx| {
                let carried = Carried::Value(event.drag(cx).value.clone());
                move_target.moved(event.event.position, event.bounds, Some(carried));
            })
            .on_drop::<DraggedValue>(move |_value, window, _cx| {
                drop_target.dropped(window.mouse_position());
            })
            .into_any_element()
    } else {
        element
            .can_drop(|value, _window, _cx| value.is::<gpui::ExternalPaths>())
            .on_drag_move::<gpui::ExternalPaths>(move |event, _window, cx| {
                let carried = bounded_paths(event.drag(cx)).map(Carried::Paths);
                move_target.moved(event.event.position, event.bounds, carried);
            })
            .on_drop::<gpui::ExternalPaths>(move |_paths, window, _cx| {
                drop_target.dropped(window.mouse_position());
            })
            .into_any_element()
    }
}

/// What a drag brings: operating-system paths, or an in-app drag source's value.
#[cfg(feature = "components")]
#[derive(Clone)]
enum Carried {
    Paths(Vec<String>),
    Value(String),
}

#[cfg(feature = "components")]
impl Carried {
    fn payload(self) -> crate::TransferPayload {
        match self {
            Carried::Paths(external_paths) => crate::TransferPayload {
                text: None,
                external_paths,
            },
            Carried::Value(value) => crate::TransferPayload {
                text: Some(value),
                external_paths: Vec::new(),
            },
        }
    }
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct TransferSession {
    session_id: u64,
    last_position: gpui::Point<gpui::Pixels>,
    carried: Carried,
}

/// One rendered target's session and the events it reports.
#[cfg(feature = "components")]
#[derive(Clone)]
struct TargetEvents {
    session: Arc<Mutex<Option<TransferSession>>>,
    runtime: crate::SharedRuntime,
    window_id: u64,
    target_id: String,
    enter: Option<String>,
    moved: Option<String>,
    leave: Option<String>,
    drop: Option<String>,
}

#[cfg(feature = "components")]
impl TargetEvents {
    fn moved(
        &self,
        position: gpui::Point<gpui::Pixels>,
        bounds: gpui::Bounds<gpui::Pixels>,
        carried: Option<Carried>,
    ) {
        let Ok(mut session) = self.session.lock() else {
            return;
        };
        if !bounds.contains(&position) {
            self.leave(&mut session, position);
            return;
        }
        if session.is_none() {
            let Some(carried) = carried else {
                return;
            };
            let session_id = NEXT_TRANSFER_SESSION_ID.fetch_add(1, Ordering::Relaxed);
            *session = Some(TransferSession {
                session_id,
                last_position: position,
                carried: carried.clone(),
            });
            if let Some(event) = self.enter.as_deref() {
                self.emit(
                    crate::InputKind::DragEnter,
                    event,
                    session_id,
                    position,
                    Some(carried.payload()),
                );
            }
        }
        if let (Some(event), Some(active)) = (self.moved.as_deref(), session.as_mut()) {
            if active.last_position == position {
                return;
            }
            active.last_position = position;
            self.emit(
                crate::InputKind::DragMove,
                event,
                active.session_id,
                position,
                None,
            );
        }
    }

    fn exited(&self) {
        let Ok(mut session) = self.session.lock() else {
            return;
        };
        if let Some(position) = session.as_ref().map(|active| active.last_position) {
            self.leave(&mut session, position);
        }
    }

    fn released_elsewhere(&self, position: gpui::Point<gpui::Pixels>) {
        let Ok(mut session) = self.session.lock() else {
            return;
        };
        if matches!(
            session.as_ref(),
            Some(TransferSession {
                carried: Carried::Value(_),
                ..
            })
        ) {
            self.leave(&mut session, position);
        }
    }

    fn dropped(&self, position: gpui::Point<gpui::Pixels>) {
        let Ok(mut session) = self.session.lock() else {
            return;
        };
        let Some(active) = session.take() else {
            return;
        };
        if let Some(event) = self.drop.as_deref() {
            self.emit(
                crate::InputKind::Drop,
                event,
                active.session_id,
                position,
                Some(active.carried.payload()),
            );
        }
    }

    fn leave(&self, session: &mut Option<TransferSession>, position: gpui::Point<gpui::Pixels>) {
        if let (Some(active), Some(event)) = (session.take(), self.leave.as_deref()) {
            self.emit(
                crate::InputKind::DragLeave,
                event,
                active.session_id,
                position,
                None,
            );
        }
    }

    fn emit(
        &self,
        kind: crate::InputKind,
        event: &str,
        session_id: u64,
        position: gpui::Point<gpui::Pixels>,
        payload: Option<crate::TransferPayload>,
    ) {
        emit_transfer(
            &self.runtime,
            kind,
            self.window_id,
            event,
            TransferEmission {
                target_id: &self.target_id,
                session_id,
                position,
                payload,
            },
        );
    }
}

#[cfg(any(feature = "components", test))]
fn bounded_path_strings<'a>(
    paths: impl IntoIterator<Item = &'a std::path::Path>,
) -> Option<Vec<String>> {
    gpui_core::transfer::bounded_path_strings(paths)
}

#[cfg(feature = "components")]
fn bounded_paths(paths: &gpui::ExternalPaths) -> Option<Vec<String>> {
    bounded_path_strings(paths.paths().iter().map(std::path::PathBuf::as_path))
}

#[cfg(feature = "components")]
struct TransferEmission<'a> {
    target_id: &'a str,
    session_id: u64,
    position: gpui::Point<gpui::Pixels>,
    payload: Option<crate::TransferPayload>,
}

#[cfg(feature = "components")]
fn emit_transfer(
    runtime: &crate::SharedRuntime,
    kind: crate::InputKind,
    window_id: u64,
    event: &str,
    emission: TransferEmission<'_>,
) {
    let _ = crate::push_event(
        runtime,
        crate::NativeEvent::Transfer {
            kind,
            window_id,
            event: event.to_string(),
            value: crate::TransferEventValue {
                session_id: emission.session_id,
                target_id: emission.target_id.to_string(),
                x: f32::from(emission.position.x) as f64,
                y: f32::from(emission.position.y) as f64,
                coordinate_space: "window_native_pixels".to_string(),
                payload: emission.payload,
            },
        },
    );
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: DropTargetComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    super::render_component_fallback(node.style, None, node.children, context)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::{Path, PathBuf};

    #[cfg(feature = "components")]
    #[gpui::test]
    fn removing_an_active_target_emits_leave_and_rejects_submit(cx: &mut gpui::TestAppContext) {
        use gpui::{point, px, size, FileDropEvent, IntoElement};
        use smallvec::smallvec;
        use std::path::PathBuf;

        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(drop_target_tree(), Vec::new()));
        let runtime_for_view = runtime.clone();
        let state_for_view = state.clone();
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state_for_view, runtime_for_view, 7, false, false)
        });
        cx.draw(
            point(px(0.0), px(0.0)),
            size(px(200.0), px(120.0)),
            |_window, _cx| view.clone().into_any_element(),
        );
        cx.simulate_event(FileDropEvent::Entered {
            position: point(px(20.0), px(20.0)),
            paths: gpui::ExternalPaths(smallvec![PathBuf::from("/display/a")]),
        });

        *state.tree.lock().unwrap() = crate::ElementNode::empty_root();
        cx.update(|window, cx| window.draw(cx).clear(cx));
        cx.simulate_event(FileDropEvent::Submit {
            position: point(px(20.0), px(20.0)),
        });

        assert_eq!(
            transfer_kinds(&runtime.events.lock().unwrap()),
            vec!["enter", "leave"]
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn stable_target_identity_survives_rerender(cx: &mut gpui::TestAppContext) {
        use gpui::{point, px, size, FileDropEvent, IntoElement};
        use smallvec::smallvec;
        use std::path::PathBuf;

        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(drop_target_tree(), Vec::new()));
        let runtime_for_view = runtime.clone();
        let state_for_view = state.clone();
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state_for_view, runtime_for_view, 7, false, false)
        });
        cx.draw(
            point(px(0.0), px(0.0)),
            size(px(200.0), px(120.0)),
            |_window, _cx| view.clone().into_any_element(),
        );
        cx.simulate_event(FileDropEvent::Entered {
            position: point(px(20.0), px(20.0)),
            paths: gpui::ExternalPaths(smallvec![PathBuf::from("/display/a")]),
        });

        *state.tree.lock().unwrap() = drop_target_tree();
        cx.update(|window, cx| window.draw(cx).clear(cx));
        cx.simulate_event(FileDropEvent::Pending {
            position: point(px(30.0), px(25.0)),
        });
        cx.simulate_event(FileDropEvent::Submit {
            position: point(px(30.0), px(25.0)),
        });

        let events = runtime.events.lock().unwrap();
        assert_eq!(transfer_kinds(&events), vec!["enter", "move", "drop"]);
        let ids = events
            .iter()
            .filter_map(|event| match event {
                crate::NativeEvent::Transfer { value, .. } => Some(value.session_id),
                _ => None,
            })
            .collect::<Vec<_>>();
        assert!(ids.iter().all(|id| *id == ids[0]));
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn rendered_target_routes_enter_move_drop_and_rejects_stale_submit(
        cx: &mut gpui::TestAppContext,
    ) {
        use gpui::{point, px, size, FileDropEvent, IntoElement};
        use smallvec::smallvec;
        use std::path::PathBuf;

        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(drop_target_tree(), Vec::new()));
        let runtime_for_view = runtime.clone();
        let state_for_view = state;
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state_for_view, runtime_for_view, 7, false, false)
        });
        cx.draw(
            point(px(0.0), px(0.0)),
            size(px(200.0), px(120.0)),
            |_window, _cx| view.clone().into_any_element(),
        );

        let position = point(px(20.0), px(20.0));
        cx.simulate_event(FileDropEvent::Entered {
            position,
            paths: gpui::ExternalPaths(smallvec![PathBuf::from("/display/a")]),
        });
        cx.simulate_event(FileDropEvent::Pending {
            position: point(px(30.0), px(25.0)),
        });
        cx.simulate_event(FileDropEvent::Submit {
            position: point(px(30.0), px(25.0)),
        });
        cx.simulate_event(FileDropEvent::Submit {
            position: point(px(30.0), px(25.0)),
        });

        let events = runtime.events.lock().unwrap();
        assert_eq!(transfer_kinds(&events), vec!["enter", "move", "drop"]);
        let session_ids = events
            .iter()
            .filter_map(|event| match event {
                crate::NativeEvent::Transfer { value, .. } => Some(value.session_id),
                _ => None,
            })
            .collect::<Vec<_>>();
        assert_eq!(session_ids.len(), 3);
        assert!(session_ids.iter().all(|id| *id == session_ids[0]));
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn rendered_target_routes_platform_exit(cx: &mut gpui::TestAppContext) {
        use gpui::{point, px, size, FileDropEvent, IntoElement};
        use smallvec::smallvec;
        use std::path::PathBuf;

        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(drop_target_tree(), Vec::new()));
        let runtime_for_view = runtime.clone();
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state, runtime_for_view, 7, false, false)
        });
        cx.draw(
            point(px(0.0), px(0.0)),
            size(px(200.0), px(120.0)),
            |_window, _cx| view.clone().into_any_element(),
        );
        cx.simulate_event(FileDropEvent::Entered {
            position: point(px(20.0), px(20.0)),
            paths: gpui::ExternalPaths(smallvec![PathBuf::from("/display/a")]),
        });
        cx.simulate_event(FileDropEvent::Exited);

        assert_eq!(
            transfer_kinds(&runtime.events.lock().unwrap()),
            vec!["enter", "leave"]
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn value_drags_enter_move_and_drop_with_their_value(cx: &mut gpui::TestAppContext) {
        use gpui::{point, px, Modifiers, MouseButton};

        let runtime = value_drag_window(cx, Some("values".to_string()), |cx| {
            cx.simulate_mouse_down(
                point(px(20.0), px(20.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(30.0), px(30.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(30.0), px(70.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(40.0), px(90.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_up(
                point(px(40.0), px(90.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
        });

        let events = runtime.events.lock().unwrap();
        assert_eq!(transfer_kinds(&events), vec!["enter", "move", "drop"]);
        let carried = Some(crate::TransferPayload {
            text: Some("sprite:a".to_string()),
            external_paths: Vec::new(),
        });
        assert_eq!(
            transfer_payloads(&events),
            vec![carried.clone(), None, carried]
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn a_value_drag_released_elsewhere_leaves(cx: &mut gpui::TestAppContext) {
        use gpui::{point, px, Modifiers, MouseButton};

        let runtime = value_drag_window(cx, Some("values".to_string()), |cx| {
            cx.simulate_mouse_down(
                point(px(20.0), px(20.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(30.0), px(30.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(30.0), px(70.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_up(
                point(px(180.0), px(20.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
        });

        assert_eq!(
            transfer_kinds(&runtime.events.lock().unwrap()),
            vec!["enter", "leave"]
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn a_file_target_ignores_value_drags(cx: &mut gpui::TestAppContext) {
        use gpui::{point, px, Modifiers, MouseButton};

        let runtime = value_drag_window(cx, None, |cx| {
            cx.simulate_mouse_down(
                point(px(20.0), px(20.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(30.0), px(30.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_move(
                point(px(30.0), px(70.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
            cx.simulate_mouse_up(
                point(px(30.0), px(70.0)),
                MouseButton::Left,
                Modifiers::none(),
            );
        });

        assert!(transfer_kinds(&runtime.events.lock().unwrap()).is_empty());
    }

    // A 160×40 drag source carrying "sprite:a" above a 160×80 drop target.
    #[cfg(feature = "components")]
    fn value_drag_window(
        cx: &mut gpui::TestAppContext,
        accepts: Option<String>,
        drive: impl FnOnce(&mut gpui::VisualTestContext),
    ) -> std::sync::Arc<crate::runtime::RuntimeState> {
        use gpui::{point, px, size, IntoElement};

        let mut source_style = crate::StyleAttrs::default();
        source_style.width = Some(gpui::px(160.0).into());
        source_style.height = Some(gpui::px(40.0).into());
        let source = crate::ElementNode::DragSourceComponent(crate::DragSourceComponentNode {
            style: source_style,
            id: "handle".to_string(),
            value: "sprite:a".to_string(),
            children: Vec::new(),
        });

        let crate::ElementNode::DropTargetComponent(mut target) = drop_target_tree() else {
            unreachable!("drop_target_tree builds a drop target");
        };
        target.accepts = accepts;

        let tree = crate::ElementNode::Div(crate::ContainerNode {
            tag: crate::GeneratedElementTag::Div,
            style: crate::StyleAttrs::default(),
            id: None,
            accessibility: crate::AccessibilitySemantics::default(),
            children: vec![source, crate::ElementNode::DropTargetComponent(target)],
            click: None,
            bounds_change: None,
            focus_request: 0,
            focus: None,
            blur: None,
            motion_request: 0,
            motion_duration: 180,
            motion_delay: 0,
            motion_easing: "ease_out".to_string(),
            motion_policy: "respect_system".to_string(),
            motion_from_opacity: 1.0,
            motion_from_x: 0.0,
            motion_from_y: 0.0,
            window_control: None,
        });

        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(tree, Vec::new()));
        let runtime_for_view = runtime.clone();
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state, runtime_for_view, 7, false, false)
        });
        cx.draw(
            point(px(0.0), px(0.0)),
            size(px(200.0), px(160.0)),
            |_window, _cx| view.clone().into_any_element(),
        );
        drive(cx);
        runtime
    }

    #[cfg(feature = "components")]
    fn transfer_payloads(events: &[crate::NativeEvent]) -> Vec<Option<crate::TransferPayload>> {
        events
            .iter()
            .filter_map(|event| match event {
                crate::NativeEvent::Transfer { value, .. } => Some(value.payload.clone()),
                _ => None,
            })
            .collect()
    }

    #[cfg(feature = "components")]
    fn drop_target_tree() -> crate::ElementNode {
        let mut style = crate::StyleAttrs::default();
        style.width = Some(gpui::px(160.0).into());
        style.height = Some(gpui::px(80.0).into());
        crate::ElementNode::DropTargetComponent(crate::DropTargetComponentNode {
            style,
            id: "drop-zone".to_string(),
            accepts: None,
            children: Vec::new(),
            drag_enter: Some("enter".to_string()),
            drag_move: Some("move".to_string()),
            drag_leave: Some("leave".to_string()),
            drop: Some("drop".to_string()),
        })
    }

    #[cfg(feature = "components")]
    fn transfer_kinds(events: &[crate::NativeEvent]) -> Vec<&str> {
        events
            .iter()
            .filter_map(|event| match event {
                crate::NativeEvent::Transfer { event, .. } => Some(event.as_str()),
                _ => None,
            })
            .collect()
    }

    #[test]
    fn bounds_and_deduplicates_external_paths() {
        let paths = [
            Path::new("/tmp/a"),
            Path::new("/tmp/a"),
            Path::new("/tmp/b"),
        ];
        assert_eq!(
            bounded_path_strings(paths),
            Some(vec!["/tmp/a".to_string(), "/tmp/b".to_string()])
        );

        let paths = (0..65)
            .map(|index| PathBuf::from(format!("/{index}")))
            .collect::<Vec<_>>();
        assert_eq!(
            bounded_path_strings(paths.iter().map(PathBuf::as_path)),
            None
        );
    }

    #[test]
    fn duplicate_paths_do_not_consume_aggregate_limit_twice() {
        let long = format!("/{}", "a".repeat(gpui_core::transfer::MAX_PATH_BYTES - 1));
        let paths = (0..gpui_core::transfer::MAX_PATHS)
            .map(|_| PathBuf::from(&long))
            .collect::<Vec<_>>();
        assert_eq!(
            bounded_path_strings(paths.iter().map(PathBuf::as_path)),
            Some(vec![long])
        );
    }
}
