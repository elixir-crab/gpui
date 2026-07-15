use crate::{atoms, SharedRuntime};
use rustler::{Atom, Encoder, Env, NifResult, Term};

#[derive(Clone, Debug)]
pub(crate) enum EventValue {
    String(String),
    Boolean(bool),
}

impl EventValue {
    fn encode<'a>(self, env: Env<'a>) -> Term<'a> {
        match self {
            Self::String(value) => value.encode(env),
            Self::Boolean(value) => value.encode(env),
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub(crate) enum InputKind {
    Change,
    KeyDown,
    KeyUp,
}

impl InputKind {
    fn atom(self) -> Atom {
        match self {
            Self::Change => atoms::change(),
            Self::KeyDown => atoms::keydown(),
            Self::KeyUp => atoms::keyup(),
        }
    }
}

#[derive(Clone, Debug)]
pub(crate) enum NativeEvent {
    Click {
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
