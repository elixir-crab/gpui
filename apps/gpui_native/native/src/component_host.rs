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
        use crate::{push_event, EventValue, InputKind, NativeEvent};

        let native = match event {
            ComponentEvent::Change(ComponentValueEvent { envelope, value }) => NativeEvent::Input {
                kind: InputKind::Change,
                window_id: envelope.window_id,
                event: envelope.event,
                value: match value {
                    ComponentValue::Boolean(value) => Some(EventValue::Boolean(value)),
                    ComponentValue::String(value) => Some(EventValue::String(value)),
                    ComponentValue::Strings(value) => Some(EventValue::Strings(value)),
                    ComponentValue::Number(value) => Some(EventValue::Number(value)),
                    ComponentValue::None => None,
                },
            },
            _event => return Ok(()),
        };
        push_event(&self.runtime, native).map_err(|_error| ComponentEventError::QueueUnavailable)
    }
}
