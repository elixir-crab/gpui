use crate::{gpui, DropTargetComponentNode, ElementRenderContext};

#[cfg(feature = "components")]
use std::sync::atomic::{AtomicU64, Ordering};

#[cfg(feature = "components")]
static NEXT_TRANSFER_SESSION_ID: AtomicU64 = AtomicU64::new(1);

#[cfg(feature = "components")]
const MAX_PATHS: usize = 64;
#[cfg(feature = "components")]
const MAX_PATH_BYTES: usize = 4_096;
#[cfg(feature = "components")]
const MAX_ALL_PATH_BYTES: usize = 262_144;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: DropTargetComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{InteractiveElement, IntoElement, ParentElement};

    let children = node
        .children
        .into_iter()
        .map(|child| child.render(context))
        .collect::<Vec<_>>();
    let session = std::sync::Arc::new(std::sync::Mutex::new(None::<TransferSession>));
    let move_session = session.clone();
    let drop_session = session;
    let move_runtime = context.runtime.clone();
    let drop_runtime = context.runtime.clone();
    let window_id = context.window_id;
    let target_id = node.id.clone();
    let move_target_id = target_id.clone();
    let move_event = node.drag_move.clone();
    let enter_event = node.drag_enter.clone();
    let leave_event = node.drag_leave.clone();
    let drop_event = node.drop.clone();

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .children(children)
        .can_drop(|value, _window, _cx| value.is::<gpui::ExternalPaths>())
        .on_drag_move::<gpui::ExternalPaths>(move |event, _window, cx| {
            let paths = bounded_paths(event.drag(cx));
            let Ok(mut session) = move_session.lock() else {
                return;
            };
            let inside = event.bounds.contains(&event.event.position);
            if !inside {
                if let Some(active) = session.take() {
                    if let Some(event_name) = leave_event.as_deref() {
                        emit_transfer(
                            &move_runtime,
                            crate::InputKind::DragLeave,
                            window_id,
                            event_name,
                            TransferEmission {
                                target_id: &move_target_id,
                                session_id: active.session_id,
                                position: event.event.position,
                                paths: None,
                            },
                        );
                    }
                }
                return;
            }
            if session.is_none() {
                let session_id = NEXT_TRANSFER_SESSION_ID.fetch_add(1, Ordering::Relaxed);
                *session = Some(TransferSession {
                    session_id,
                    last_position: None,
                });
                if let (Some(event_name), Some(paths)) = (enter_event.as_deref(), paths.as_ref()) {
                    emit_transfer(
                        &move_runtime,
                        crate::InputKind::DragEnter,
                        window_id,
                        event_name,
                        TransferEmission {
                            target_id: &move_target_id,
                            session_id,
                            position: event.event.position,
                            paths: Some(paths.clone()),
                        },
                    );
                }
            }
            if let (Some(event_name), Some(session)) = (move_event.as_deref(), session.as_mut()) {
                let position = (
                    f32::from(event.event.position.x),
                    f32::from(event.event.position.y),
                );
                if session.last_position == Some(position) {
                    return;
                }
                session.last_position = Some(position);
                emit_transfer(
                    &move_runtime,
                    crate::InputKind::DragMove,
                    window_id,
                    event_name,
                    TransferEmission {
                        target_id: &move_target_id,
                        session_id: session.session_id,
                        position: event.event.position,
                        paths: None,
                    },
                );
            }
        })
        .on_drop::<gpui::ExternalPaths>(move |paths, window, _cx| {
            let Ok(mut session) = drop_session.lock() else {
                return;
            };
            let session_id = session
                .take()
                .map(|session| session.session_id)
                .unwrap_or_else(|| NEXT_TRANSFER_SESSION_ID.fetch_add(1, Ordering::Relaxed));
            if let (Some(event_name), Some(paths)) = (drop_event.as_deref(), bounded_paths(paths)) {
                emit_transfer(
                    &drop_runtime,
                    crate::InputKind::Drop,
                    window_id,
                    event_name,
                    TransferEmission {
                        target_id: &target_id,
                        session_id,
                        position: window.mouse_position(),
                        paths: Some(paths),
                    },
                );
            }
        })
        .into_any_element()
}

#[cfg(feature = "components")]
#[derive(Clone, Copy)]
struct TransferSession {
    session_id: u64,
    last_position: Option<(f32, f32)>,
}

#[cfg(feature = "components")]
fn bounded_paths(paths: &gpui::ExternalPaths) -> Option<Vec<String>> {
    let mut result = Vec::new();
    let mut total = 0;
    for path in paths.paths() {
        if result.len() >= MAX_PATHS {
            return None;
        }
        let path = path.to_str()?;
        let bytes = path.len();
        if path.is_empty() || bytes > MAX_PATH_BYTES || total + bytes > MAX_ALL_PATH_BYTES {
            return None;
        }
        total += bytes;
        if !result.iter().any(|existing| existing == path) {
            result.push(path.to_string());
        }
    }
    Some(result)
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
    use smallvec::smallvec;
    use std::path::PathBuf;

    #[test]
    fn bounds_and_deduplicates_external_paths() {
        let paths = gpui::ExternalPaths(smallvec![
            PathBuf::from("/tmp/a"),
            PathBuf::from("/tmp/a"),
            PathBuf::from("/tmp/b")
        ]);
        assert_eq!(
            bounded_paths(&paths),
            Some(vec!["/tmp/a".to_string(), "/tmp/b".to_string()])
        );

        let paths = gpui::ExternalPaths(
            (0..65)
                .map(|index| PathBuf::from(format!("/{index}")))
                .collect(),
        );
        assert_eq!(bounded_paths(&paths), None);
    }
}
