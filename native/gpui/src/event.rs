use crate::{atoms, SharedRuntime};
use rustler::{Atom, Encoder, Env, NifResult, Term};

#[derive(Clone, Debug)]
pub(crate) enum NativeEvent {
    Click {
        window_id: u64,
        event: String,
    },
    Input {
        kind: String,
        window_id: u64,
        event: String,
        value: Option<String>,
    },
    WindowClosed {
        window_id: u64,
    },
    #[cfg(feature = "real-gpui")]
    MissingResource {
        window_id: u64,
        id: String,
        resource_type: String,
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
    let type_key = Atom::from_bytes(env, b"type")?;
    let window_id_key = Atom::from_bytes(env, b"window_id")?;

    match event {
        NativeEvent::Click { window_id, event } => encode_event_map(
            env,
            vec![
                (type_key, atoms::click().to_term(env)),
                (window_id_key, window_id.encode(env)),
                (Atom::from_bytes(env, b"event")?, event.encode(env)),
            ],
        ),
        NativeEvent::Input {
            kind,
            window_id,
            event,
            value,
        } => {
            let mut entries = vec![
                (
                    type_key,
                    Atom::from_bytes(env, kind.as_bytes())?.to_term(env),
                ),
                (window_id_key, window_id.encode(env)),
                (Atom::from_bytes(env, b"event")?, event.encode(env)),
            ];

            if let Some(value) = value {
                entries.push((Atom::from_bytes(env, b"value")?, value.encode(env)));
            }

            encode_event_map(env, entries)
        }
        NativeEvent::WindowClosed { window_id } => encode_event_map(
            env,
            vec![
                (type_key, atoms::window_closed().to_term(env)),
                (window_id_key, window_id.encode(env)),
            ],
        ),
        #[cfg(feature = "real-gpui")]
        NativeEvent::MissingResource {
            window_id,
            id,
            resource_type,
        } => encode_event_map(
            env,
            vec![
                (
                    type_key,
                    Atom::from_bytes(env, b"missing_resource")?.to_term(env),
                ),
                (window_id_key, window_id.encode(env)),
                (Atom::from_bytes(env, b"id")?, id.encode(env)),
                (
                    Atom::from_bytes(env, b"resource_type")?,
                    Atom::from_bytes(env, resource_type.as_bytes())?.to_term(env),
                ),
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
