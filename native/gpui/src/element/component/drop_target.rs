use crate::{gpui, DropTargetComponentNode, ElementRenderContext};

#[cfg(feature = "components")]
use std::sync::atomic::{AtomicU64, Ordering};
#[cfg(feature = "components")]
use std::sync::{Arc, Mutex};

#[cfg(feature = "components")]
static NEXT_TRANSFER_SESSION_ID: AtomicU64 = AtomicU64::new(1);

#[cfg(any(feature = "components", test))]
const MAX_PATHS: usize = 64;
#[cfg(any(feature = "components", test))]
const MAX_PATH_BYTES: usize = 4_096;
#[cfg(any(feature = "components", test))]
const MAX_ALL_PATH_BYTES: usize = 262_144;

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
                    paths: None,
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
    let move_session = component.session.clone();
    let drop_session = component.session.clone();
    let exit_session = component.session.clone();

    let children = node
        .children
        .into_iter()
        .map(|child| child.render(context))
        .collect::<Vec<_>>();
    let move_runtime = context.runtime.clone();
    let drop_runtime = context.runtime.clone();
    let exit_runtime = context.runtime.clone();
    let window_id = context.window_id;
    let target_id = node.id.clone();
    let move_target_id = target_id.clone();
    let exit_target_id = target_id.clone();
    let move_event = node.drag_move.clone();
    let enter_event = node.drag_enter.clone();
    let leave_event = node.drag_leave.clone();
    let exit_event = node.drag_leave.clone();
    let drop_event = node.drop.clone();

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .children(children)
        .child(gpui::canvas(
            |_bounds, _window, _cx| (),
            move |_bounds, (), window, _cx| {
                let session = exit_session.clone();
                let runtime = exit_runtime.clone();
                let event = exit_event.clone();
                let target_id = exit_target_id.clone();
                window.on_mouse_event(
                    move |file_event: &gpui::FileDropEvent, phase, _window, _cx| {
                        if phase != gpui::DispatchPhase::Bubble
                            || !matches!(file_event, gpui::FileDropEvent::Exited)
                        {
                            return;
                        }
                        let Ok(mut session) = session.lock() else {
                            return;
                        };
                        let position = session.as_ref().map(|active| active.last_position);
                        if let Some(position) = position {
                            terminate_session(
                                &mut session,
                                &runtime,
                                window_id,
                                event.as_deref(),
                                &target_id,
                                position,
                            );
                        }
                    },
                );
            },
        ))
        .can_drop(|value, _window, _cx| value.is::<gpui::ExternalPaths>())
        .on_drag_move::<gpui::ExternalPaths>(move |event, _window, cx| {
            let paths = bounded_paths(event.drag(cx));
            let Ok(mut session) = move_session.lock() else {
                return;
            };
            let position = event.event.position;
            if !event.bounds.contains(&position) {
                terminate_session(
                    &mut session,
                    &move_runtime,
                    window_id,
                    leave_event.as_deref(),
                    &move_target_id,
                    position,
                );
                return;
            }
            if session.is_none() {
                let Some(paths) = paths else {
                    return;
                };
                let session_id = NEXT_TRANSFER_SESSION_ID.fetch_add(1, Ordering::Relaxed);
                *session = Some(TransferSession {
                    session_id,
                    last_position: position,
                    paths: paths.clone(),
                });
                if let Some(event_name) = enter_event.as_deref() {
                    emit_transfer(
                        &move_runtime,
                        crate::InputKind::DragEnter,
                        window_id,
                        event_name,
                        TransferEmission {
                            target_id: &move_target_id,
                            session_id,
                            position,
                            paths: Some(paths),
                        },
                    );
                }
            }
            if let (Some(event_name), Some(session)) = (move_event.as_deref(), session.as_mut()) {
                if session.last_position == position {
                    return;
                }
                session.last_position = position;
                emit_transfer(
                    &move_runtime,
                    crate::InputKind::DragMove,
                    window_id,
                    event_name,
                    TransferEmission {
                        target_id: &move_target_id,
                        session_id: session.session_id,
                        position,
                        paths: None,
                    },
                );
            }
        })
        .on_drop::<gpui::ExternalPaths>(move |_paths, window, _cx| {
            let Ok(mut session) = drop_session.lock() else {
                return;
            };
            let Some(active) = session.take() else {
                return;
            };
            if let Some(event_name) = drop_event.as_deref() {
                emit_transfer(
                    &drop_runtime,
                    crate::InputKind::Drop,
                    window_id,
                    event_name,
                    TransferEmission {
                        target_id: &target_id,
                        session_id: active.session_id,
                        position: window.mouse_position(),
                        paths: Some(active.paths),
                    },
                );
            }
        })
        .into_any_element()
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct TransferSession {
    session_id: u64,
    last_position: gpui::Point<gpui::Pixels>,
    paths: Vec<String>,
}

#[cfg(feature = "components")]
fn terminate_session(
    session: &mut Option<TransferSession>,
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&str>,
    target_id: &str,
    position: gpui::Point<gpui::Pixels>,
) {
    if let (Some(active), Some(event)) = (session.take(), event) {
        emit_transfer(
            runtime,
            crate::InputKind::DragLeave,
            window_id,
            event,
            TransferEmission {
                target_id,
                session_id: active.session_id,
                position,
                paths: None,
            },
        );
    }
}

#[cfg(any(feature = "components", test))]
fn bounded_path_strings<'a>(
    paths: impl IntoIterator<Item = &'a std::path::Path>,
) -> Option<Vec<String>> {
    let mut result = Vec::new();
    let mut total = 0;
    for path in paths {
        if result.len() >= MAX_PATHS {
            return None;
        }
        let path = path.to_str()?;
        let bytes = path.len();
        if path.is_empty() || bytes > MAX_PATH_BYTES || total + bytes > MAX_ALL_PATH_BYTES {
            return None;
        }
        if !result.iter().any(|existing| existing == path) {
            total += bytes;
            result.push(path.to_string());
        }
    }
    Some(result)
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
    paths: Option<Vec<String>>,
}

#[cfg(feature = "components")]
fn emit_transfer(
    runtime: &crate::SharedRuntime,
    kind: crate::InputKind,
    window_id: u64,
    event: &str,
    emission: TransferEmission<'_>,
) {
    let payload = emission.paths.map(|external_paths| crate::TransferPayload {
        text: None,
        external_paths,
    });
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
                payload,
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
    fn drop_target_tree() -> crate::ElementNode {
        let mut style = crate::StyleAttrs::default();
        style.width = Some(gpui::px(160.0).into());
        style.height = Some(gpui::px(80.0).into());
        crate::ElementNode::DropTargetComponent(crate::DropTargetComponentNode {
            style,
            id: "drop-zone".to_string(),
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
        let long = format!("/{}", "a".repeat(MAX_PATH_BYTES - 1));
        let paths = (0..MAX_PATHS)
            .map(|_| PathBuf::from(&long))
            .collect::<Vec<_>>();
        assert_eq!(
            bounded_path_strings(paths.iter().map(PathBuf::as_path)),
            Some(vec![long])
        );
    }
}
