use crate::{atoms, RuntimeResource};
use rustler::{Atom, Encoder, Env, NifResult, ResourceArc, Term};

#[derive(Clone, Debug)]
pub(crate) enum NativeEvent {
    Text(String),
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
    #[cfg(feature = "real-gpui")]
    MissingResource {
        window_id: u64,
        id: String,
        resource_type: String,
    },
    WindowUpdated {
        window_id: u64,
    },
}

pub(crate) fn push_text_event(
    runtime: &ResourceArc<RuntimeResource>,
    event: String,
) -> NifResult<()> {
    push_event(runtime, NativeEvent::Text(event))
}

pub(crate) fn push_event(
    runtime: &ResourceArc<RuntimeResource>,
    event: NativeEvent,
) -> NifResult<()> {
    runtime
        .events
        .lock()
        .map_err(|_| rustler::Error::Term(Box::new("runtime_lock_failed")))?
        .push(event);

    Ok(())
}

pub(crate) fn encode_native_event<'a>(env: Env<'a>, event: NativeEvent) -> NifResult<Term<'a>> {
    match event {
        NativeEvent::Text(text) => Ok(text.encode(env)),
        NativeEvent::Click { window_id, event } => Ok(vec![
            (Atom::from_bytes(env, b"type")?, atoms::click().to_term(env)),
            (Atom::from_bytes(env, b"window_id")?, window_id.encode(env)),
            (Atom::from_bytes(env, b"event")?, event.encode(env)),
        ]
        .encode(env)),
        NativeEvent::Input {
            kind,
            window_id,
            event,
            value,
        } => {
            let type_atom = Atom::from_bytes(env, kind.as_bytes())?;
            let mut entries = vec![
                (Atom::from_bytes(env, b"type")?, type_atom.to_term(env)),
                (Atom::from_bytes(env, b"window_id")?, window_id.encode(env)),
                (Atom::from_bytes(env, b"event")?, event.encode(env)),
            ];

            if let Some(value) = value {
                entries.push((Atom::from_bytes(env, b"value")?, value.encode(env)));
            }

            Ok(entries.encode(env))
        }
        #[cfg(feature = "real-gpui")]
        NativeEvent::MissingResource {
            window_id,
            id,
            resource_type,
        } => Ok(vec![
            (
                Atom::from_bytes(env, b"type")?,
                Atom::from_bytes(env, b"missing_resource")?.to_term(env),
            ),
            (Atom::from_bytes(env, b"window_id")?, window_id.encode(env)),
            (Atom::from_bytes(env, b"id")?, id.encode(env)),
            (
                Atom::from_bytes(env, b"resource_type")?,
                Atom::from_bytes(env, resource_type.as_bytes())?.to_term(env),
            ),
        ]
        .encode(env)),
        NativeEvent::WindowUpdated { window_id } => Ok(vec![
            (
                Atom::from_bytes(env, b"type")?,
                atoms::window_updated().to_term(env),
            ),
            (Atom::from_bytes(env, b"window_id")?, window_id.encode(env)),
        ]
        .encode(env)),
    }
}
