#[cfg(feature = "components")]
use gpui_components::host_contract::{
    ComponentEvent, ComponentEventError, ComponentEventSink, ComponentValue, ComponentValueEvent,
};

#[cfg(feature = "components")]
pub(crate) struct NifComponentEventSink {
    runtime: crate::SharedRuntime,
}

#[cfg(feature = "components")]
impl NifComponentEventSink {
    pub(crate) fn new(runtime: crate::SharedRuntime) -> Self {
        Self { runtime }
    }
}

#[cfg(feature = "components")]
impl ComponentEventSink for NifComponentEventSink {
    fn emit(&self, event: ComponentEvent) -> Result<(), ComponentEventError> {
        use crate::{push_event, InputKind};

        let native = match event {
            ComponentEvent::Change(value) => value_event(InputKind::Change, value),
            ComponentEvent::Release(value) => value_event(InputKind::Release, value),
            _event => return Ok(()),
        };
        push_event(&self.runtime, native).map_err(|_error| ComponentEventError::QueueUnavailable)
    }
}

#[cfg(feature = "components")]
fn value_event(kind: crate::InputKind, value: ComponentValueEvent) -> crate::NativeEvent {
    use crate::{EventValue, NativeEvent};

    NativeEvent::Input {
        kind,
        window_id: value.envelope.window_id,
        event: value.envelope.event,
        value: match value.value {
            ComponentValue::Boolean(value) => Some(EventValue::Boolean(value)),
            ComponentValue::String(value) => Some(EventValue::String(value)),
            ComponentValue::Strings(value) => Some(EventValue::Strings(value)),
            ComponentValue::Number(value) => Some(EventValue::Number(value)),
            ComponentValue::None => None,
        },
    }
}
