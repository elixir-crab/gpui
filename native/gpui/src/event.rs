use crate::{atoms, SharedRuntime};
use rustler::{Atom, Encoder, Env, NifResult, Term};

#[cfg(feature = "components")]
use crate::element::component::display::FileDialogResult;

include!("generated/events.rs");

#[derive(Clone, Debug)]
pub(crate) enum NativeEvent {
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
    runtime
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .push(event);

    Ok(())
}

pub(crate) fn encode_native_event<'a>(env: Env<'a>, event: NativeEvent) -> NifResult<Term<'a>> {
    match event {
        NativeEvent::Click { window_id, event } => encode_event_map(
            env,
            vec![
                (atoms::type_atom(), atoms::click().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
                (atoms::event(), event.encode(env)),
            ],
        ),
        NativeEvent::Command { window_id, event } => encode_event_map(
            env,
            vec![
                (atoms::type_atom(), atoms::command().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
                (atoms::event(), event.encode(env)),
            ],
        ),
        NativeEvent::Input {
            kind,
            window_id,
            event,
            value,
        } => {
            let mut entries = vec![
                (atoms::type_atom(), kind.atom().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
                (atoms::event(), event.encode(env)),
            ];

            if let Some(value) = value {
                entries.push((atoms::value(), value.encode(env)));
            }

            encode_event_map(env, entries)
        }
        NativeEvent::WindowClosed { window_id } => encode_event_map(
            env,
            vec![
                (atoms::type_atom(), atoms::window_closed().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
            ],
        ),
        #[cfg(feature = "components")]
        NativeEvent::VirtualRange {
            window_id,
            event,
            first,
            last,
        } => encode_event_map(
            env,
            vec![
                (atoms::type_atom(), atoms::range().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
                (atoms::event(), event.encode(env)),
                (
                    atoms::value(),
                    encode_event_map(
                        env,
                        vec![
                            (atoms::first(), first.encode(env)),
                            (atoms::last(), last.encode(env)),
                        ],
                    )?,
                ),
            ],
        ),
        #[cfg(feature = "components")]
        NativeEvent::FileDialog {
            window_id,
            event,
            operation_id,
            result,
        } => encode_event_map(
            env,
            vec![
                (atoms::type_atom(), atoms::change().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
                (atoms::event(), event.encode(env)),
                (
                    atoms::value(),
                    encode_file_dialog_result(env, operation_id, result)?,
                ),
            ],
        ),
        #[cfg(feature = "real-gpui")]
        NativeEvent::MissingResource { window_id, id } => encode_event_map(
            env,
            vec![
                (atoms::type_atom(), atoms::missing_resource().to_term(env)),
                (atoms::window_id(), window_id.encode(env)),
                (atoms::id(), id.encode(env)),
                (atoms::resource_type(), atoms::raster().to_term(env)),
            ],
        ),
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

            encode_event_map(
                env,
                vec![
                    (atoms::operation_id(), operation_id.encode(env)),
                    (atoms::status(), atoms::selected().to_term(env)),
                    (atoms::name(), name.encode(env)),
                    (atoms::size(), size.encode(env)),
                    (atoms::data(), binary.release(env).encode(env)),
                ],
            )
        }
        FileDialogResult::Cancelled => encode_event_map(
            env,
            vec![
                (atoms::operation_id(), operation_id.encode(env)),
                (atoms::status(), atoms::cancelled().to_term(env)),
            ],
        ),
        FileDialogResult::Error(reason) => encode_event_map(
            env,
            vec![
                (atoms::operation_id(), operation_id.encode(env)),
                (atoms::status(), atoms::error().to_term(env)),
                (atoms::reason(), reason.encode(env)),
            ],
        ),
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
