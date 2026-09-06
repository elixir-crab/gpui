#[derive(Clone, Debug, PartialEq)]
pub struct ComponentEventEnvelope {
    pub window_id: u64,
    pub event: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ComponentValueEvent {
    pub envelope: ComponentEventEnvelope,
    pub value: ComponentValue,
}

macro_rules! opaque_event {
    ($($name:ident),+ $(,)?) => {$(
        #[derive(Clone, Debug, PartialEq)]
        pub struct $name { pub envelope: ComponentEventEnvelope }
    )+};
}
opaque_event!(
    ComponentInputEvent,
    ComponentTransferEvent,
    ComponentFileDialogEvent,
    ComponentTextGeometryEvent,
    ComponentTextPositionEvent,
    ComponentTextRangeGeometryEvent,
    ComponentTextSelectionEvent,
    ComponentTextTransactionEvent,
    ComponentTextViewportEvent,
);

include!("generated/host_contract.rs");

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ComponentEventError {
    QueueUnavailable,
}

pub trait ComponentEventSink: Send + Sync {
    fn emit(&self, event: ComponentEvent) -> Result<(), ComponentEventError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn envelope_access_preserves_direct_and_wrapped_payload_identity() {
        let envelope = ComponentEventEnvelope {
            window_id: u64::MAX,
            event: "event-λ".into(),
        };
        let direct = ComponentEvent::Click(envelope.clone());
        assert_eq!(direct.envelope(), &envelope);
        if let ComponentEvent::Click(ref stored) = direct {
            assert!(std::ptr::eq(direct.envelope(), stored));
        }
        let wrapped = ComponentEvent::Change(ComponentValueEvent {
            envelope: envelope.clone(),
            value: ComponentValue::String("value".into()),
        });
        assert_eq!(wrapped.envelope(), &envelope);
        if let ComponentEvent::Change(ref stored) = wrapped {
            assert!(std::ptr::eq(wrapped.envelope(), &stored.envelope));
        }
    }

    #[test]
    fn generated_events_use_schema_owned_payload_shapes() {
        let event = ComponentEvent::Change(ComponentValueEvent {
            envelope: ComponentEventEnvelope {
                window_id: 7,
                event: "save".into(),
            },
            value: ComponentValue::Boolean(true),
        });
        assert_eq!(event.envelope().window_id, 7);
        assert_eq!(event.envelope().event, "save");
    }
}
