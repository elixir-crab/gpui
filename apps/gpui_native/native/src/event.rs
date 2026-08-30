use crate::{atoms, SharedRuntime};
#[cfg(feature = "components")]
use crate::{TextPosition, TextSelection, TextTransaction};
#[cfg(feature = "components")]
use rustler::NifMap;
use rustler::{Atom, Encoder, Env, NifResult, Term};

#[cfg(feature = "components")]
#[derive(Clone, Debug, NifMap)]
pub(crate) struct TextViewportGeometry {
    pub(crate) first_visible_row: u64,
    pub(crate) last_visible_row: u64,
    pub(crate) scroll_x: f64,
    pub(crate) scroll_y: f64,
    pub(crate) line_height: f64,
}

#[cfg(feature = "components")]
#[derive(Clone, Debug, NifMap)]
pub(crate) struct TextCaretGeometry {
    pub(crate) line: u64,
    pub(crate) utf16_offset: u64,
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) width: f64,
    pub(crate) height: f64,
}

#[cfg(feature = "components")]
#[derive(Clone, Debug, NifMap)]
pub(crate) struct TextRectangle {
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) width: f64,
    pub(crate) height: f64,
}

#[cfg(feature = "components")]
#[derive(Clone, Debug, NifMap)]
pub(crate) struct TextRangeGeometry {
    pub(crate) range: crate::TextRange,
    pub(crate) rectangles: Vec<TextRectangle>,
}

#[cfg(feature = "components")]
use crate::element::component::display::FileDialogResult;

include!("generated/events.rs");

#[cfg(feature = "real-gpui")]
#[derive(Clone, Debug, PartialEq, rustler::NifMap)]
pub(crate) struct ElementBoundsGeometry {
    pub(crate) id: String,
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) width: f64,
    pub(crate) height: f64,
    pub(crate) coordinate_space: String,
}

#[cfg_attr(not(feature = "components"), allow(dead_code))]
#[derive(Clone, Debug, PartialEq, rustler::NifMap)]
pub(crate) struct TransferPayload {
    pub(crate) text: Option<String>,
    pub(crate) external_paths: Vec<String>,
}

#[cfg_attr(not(feature = "components"), allow(dead_code))]
#[derive(Clone, Debug, PartialEq, rustler::NifMap)]
pub(crate) struct TransferEventValue {
    pub(crate) session_id: u64,
    pub(crate) target_id: String,
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) coordinate_space: String,
    pub(crate) payload: Option<TransferPayload>,
}

#[derive(Clone, Debug)]
pub(crate) enum NativeEvent {
    #[cfg(feature = "components")]
    Copy {
        window_id: u64,
        event: String,
    },
    Click {
        window_id: u64,
        event: String,
    },
    Command {
        window_id: u64,
        event: String,
    },
    Input {
        kind: InputKind,
        window_id: u64,
        event: String,
        value: Option<EventValue>,
    },
    #[cfg(feature = "components")]
    Transaction {
        window_id: u64,
        event: String,
        transaction: TextTransaction,
        revision: u64,
    },
    #[cfg(feature = "components")]
    Selection {
        window_id: u64,
        event: String,
        selections: Vec<crate::TextSelection>,
        revision: u64,
    },
    #[cfg(feature = "components")]
    Viewport {
        window_id: u64,
        event: String,
        value: TextViewportGeometry,
        revision: u64,
    },
    #[cfg(feature = "components")]
    Geometry {
        window_id: u64,
        event: String,
        value: TextCaretGeometry,
        revision: u64,
    },
    #[cfg(feature = "components")]
    RangeGeometry {
        window_id: u64,
        event: String,
        value: Vec<TextRangeGeometry>,
        revision: u64,
    },
    #[cfg(feature = "components")]
    HitTest {
        window_id: u64,
        event: String,
        value: crate::TextPosition,
        revision: u64,
    },
    #[cfg(feature = "real-gpui")]
    Focus {
        kind: InputKind,
        window_id: u64,
        event: String,
        id: String,
    },
    #[cfg(feature = "real-gpui")]
    Bounds {
        window_id: u64,
        event: String,
        value: ElementBoundsGeometry,
    },
    #[cfg(feature = "components")]
    ClipboardWrite {
        window_id: u64,
        event: String,
    },
    #[cfg(feature = "components")]
    ClipboardRead {
        window_id: u64,
        event: String,
        payload: TransferPayload,
    },
    #[cfg(feature = "components")]
    Transfer {
        kind: InputKind,
        window_id: u64,
        event: String,
        value: TransferEventValue,
    },
    WindowCloseRequest {
        window_id: u64,
    },
    WindowFocus {
        focused: bool,
        window_id: u64,
    },
    WindowClosed {
        window_id: u64,
    },
    #[cfg(feature = "components")]
    VirtualRange {
        window_id: u64,
        event: String,
        first: u64,
        last: u64,
    },
    #[cfg(feature = "components")]
    FileDialog {
        window_id: u64,
        event: String,
        operation_id: u64,
        result: FileDialogResult,
    },
    #[cfg(feature = "real-gpui")]
    MissingResource {
        window_id: u64,
        id: String,
    },
}

pub(crate) fn push_event(runtime: &SharedRuntime, event: NativeEvent) -> NifResult<()> {
    let mut events = runtime
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?;

    #[cfg(feature = "components")]
    if let NativeEvent::Transfer {
        kind: InputKind::DragMove,
        window_id,
        value,
        ..
    } = &event
    {
        if let Some(pending) = events.iter_mut().rev().find(|pending| {
            matches!(
                pending,
                NativeEvent::Transfer {
                    kind: InputKind::DragMove,
                    window_id: pending_window_id,
                    value: pending_value,
                    ..
                } if pending_window_id == window_id
                    && pending_value.session_id == value.session_id
                    && pending_value.target_id == value.target_id
            )
        }) {
            *pending = event;
            return Ok(());
        }
    }

    events.push(event);

    Ok(())
}

pub(crate) fn encode_native_event<'a>(env: Env<'a>, event: NativeEvent) -> NifResult<Term<'a>> {
    match event {
        #[cfg(feature = "components")]
        NativeEvent::Copy { window_id, event } => {
            encode_named_event(env, atoms::copy(), window_id, event)
        }
        NativeEvent::Click { window_id, event } => {
            encode_named_event(env, atoms::click(), window_id, event)
        }
        NativeEvent::Command { window_id, event } => {
            encode_named_event(env, atoms::command(), window_id, event)
        }
        NativeEvent::Input {
            kind,
            window_id,
            event,
            value,
        } => encode_input_event(env, &kind, window_id, event, value),
        #[cfg(feature = "components")]
        NativeEvent::Transaction {
            window_id,
            event,
            transaction,
            revision,
        } => encode_revisioned_transaction_event(
            env,
            atoms::transaction(),
            window_id,
            event,
            transaction,
            revision,
        ),
        #[cfg(feature = "components")]
        NativeEvent::Selection {
            window_id,
            event,
            selections,
            revision,
        } => encode_revisioned_selection_event(
            env,
            atoms::selection(),
            window_id,
            event,
            selections,
            revision,
        ),
        #[cfg(feature = "components")]
        NativeEvent::Viewport {
            window_id,
            event,
            value,
            revision,
        } => encode_revisioned_viewport_event(
            env,
            atoms::viewport(),
            window_id,
            event,
            value,
            revision,
        ),
        #[cfg(feature = "components")]
        NativeEvent::Geometry {
            window_id,
            event,
            value,
            revision,
        } => encode_revisioned_geometry_event(
            env,
            atoms::geometry(),
            window_id,
            event,
            value,
            revision,
        ),
        #[cfg(feature = "components")]
        NativeEvent::RangeGeometry {
            window_id,
            event,
            value,
            revision,
        } => encode_revisioned_range_geometry_event(
            env,
            atoms::range_geometry(),
            window_id,
            event,
            value,
            revision,
        ),
        #[cfg(feature = "components")]
        NativeEvent::HitTest {
            window_id,
            event,
            value,
            revision,
        } => encode_revisioned_position_event(
            env,
            atoms::hit_test(),
            window_id,
            event,
            value,
            revision,
        ),
        #[cfg(feature = "real-gpui")]
        NativeEvent::Focus {
            kind,
            window_id,
            event,
            id,
        } => encode_focus_event(env, &kind, window_id, event, id),
        #[cfg(feature = "real-gpui")]
        NativeEvent::Bounds {
            window_id,
            event,
            value,
        } => encode_bounds_event(env, window_id, event, value),
        #[cfg(feature = "components")]
        NativeEvent::ClipboardWrite { window_id, event } => {
            encode_named_event(env, atoms::clipboard_write(), window_id, event)
        }
        #[cfg(feature = "components")]
        NativeEvent::ClipboardRead {
            window_id,
            event,
            payload,
        } => encode_clipboard_event(env, window_id, event, payload),
        #[cfg(feature = "components")]
        NativeEvent::Transfer {
            kind,
            window_id,
            event,
            value,
        } => encode_transfer_event(env, &kind, window_id, event, value),
        NativeEvent::WindowCloseRequest { window_id } => {
            encode_window_event(env, atoms::window_close_request(), window_id)
        }
        NativeEvent::WindowFocus { focused, window_id } => encode_window_event(
            env,
            if focused {
                atoms::window_focus()
            } else {
                atoms::window_blur()
            },
            window_id,
        ),
        NativeEvent::WindowClosed { window_id } => {
            encode_window_event(env, atoms::window_closed(), window_id)
        }
        #[cfg(feature = "components")]
        NativeEvent::VirtualRange {
            window_id,
            event,
            first,
            last,
        } => encode_virtual_range_event(env, window_id, event, first, last),
        #[cfg(feature = "components")]
        NativeEvent::FileDialog {
            window_id,
            event,
            operation_id,
            result,
        } => encode_file_dialog_event(
            env,
            window_id,
            event,
            encode_file_dialog_result(env, operation_id, result)?,
        ),
        #[cfg(feature = "real-gpui")]
        NativeEvent::MissingResource { window_id, id } => {
            encode_missing_resource_event(env, window_id, id)
        }
    }
}

#[cfg(feature = "components")]
fn encode_file_dialog_result(
    env: Env,
    operation_id: u64,
    result: FileDialogResult,
) -> NifResult<Term> {
    match result {
        FileDialogResult::Selected { name, data } => {
            let size = data.len() as u64;
            let mut binary = rustler::OwnedBinary::new(data.len())
                .ok_or_else(|| rustler::Error::Term(Box::new("file_allocation_failed")))?;
            binary.as_mut_slice().copy_from_slice(&data);

            encode_file_dialog_selected(
                env,
                operation_id,
                name,
                size,
                binary.release(env).encode(env),
            )
        }
        FileDialogResult::Cancelled => encode_file_dialog_cancelled(env, operation_id),
        FileDialogResult::Error(reason) => encode_file_dialog_error(env, operation_id, reason),
    }
}

fn encode_event_map<'a>(env: Env<'a>, entries: Vec<(Atom, Term<'a>)>) -> NifResult<Term<'a>> {
    let keys = entries
        .iter()
        .map(|(key, _value)| key.to_term(env))
        .collect::<Vec<_>>();
    let values = entries
        .into_iter()
        .map(|(_key, value)| value)
        .collect::<Vec<_>>();

    Term::map_from_term_arrays(env, &keys, &values)
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::*;

    fn movement(session_id: u64, target_id: &str, x: f64) -> NativeEvent {
        NativeEvent::Transfer {
            kind: InputKind::DragMove,
            window_id: 7,
            event: "move".to_string(),
            value: TransferEventValue {
                session_id,
                target_id: target_id.to_string(),
                x,
                y: 2.0,
                coordinate_space: "window_native_pixels".to_string(),
                payload: None,
            },
        }
    }

    #[test]
    fn coalesces_latest_drag_movement_per_session_and_target() {
        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        push_event(&runtime, movement(10, "left", 1.0)).unwrap();
        push_event(&runtime, movement(10, "left", 3.0)).unwrap();
        push_event(&runtime, movement(11, "left", 4.0)).unwrap();
        push_event(&runtime, movement(10, "right", 5.0)).unwrap();

        let events = runtime.events.lock().unwrap();
        assert_eq!(events.len(), 3);
        assert!(matches!(
            &events[0],
            NativeEvent::Transfer { value, .. } if value.session_id == 10
                && value.target_id == "left" && value.x == 3.0
        ));
    }

    #[test]
    fn terminal_transfer_facts_are_not_coalesced() {
        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        push_event(&runtime, movement(10, "target", 1.0)).unwrap();
        push_event(
            &runtime,
            NativeEvent::Transfer {
                kind: InputKind::DragLeave,
                window_id: 7,
                event: "leave".to_string(),
                value: TransferEventValue {
                    session_id: 10,
                    target_id: "target".to_string(),
                    x: 2.0,
                    y: 2.0,
                    coordinate_space: "window_native_pixels".to_string(),
                    payload: None,
                },
            },
        )
        .unwrap();

        assert_eq!(runtime.events.lock().unwrap().len(), 2);
    }
}
