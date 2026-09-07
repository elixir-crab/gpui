use crate::{atoms, SharedRuntime};
#[cfg(feature = "components")]
use crate::{TextPosition, TextSelection, TextTransaction};
#[cfg(feature = "components")]
use rustler::NifMap;
use rustler::{Atom, Encoder, Env, NifResult, Term};

include!("generated/event_geometry.rs");

#[cfg(feature = "components")]
use crate::element::component::display::FileDialogResult;

include!("generated/events.rs");

include!("generated/event_payloads.rs");

include!("generated/event_contract.rs");

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
