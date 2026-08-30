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

impl ComponentEvent {
    pub fn envelope(&self) -> &ComponentEventEnvelope {
        match self {
            Self::DragEnter(value) => &value.envelope,
            Self::DragMove(value) => &value.envelope,
            Self::DragLeave(value) => &value.envelope,
            Self::Drop(value) => &value.envelope,
            Self::Change(value) => &value.envelope,
            Self::Click(value) => value,
            Self::Clipboard(value) => &value.envelope,
            Self::ClipboardWrite(value) => value,
            Self::FileRead(value) => &value.envelope,
            Self::Select(value) => &value.envelope,
            Self::Submit(value) => &value.envelope,
            Self::Focus(value) => value,
            Self::Blur(value) => value,
            Self::Search(value) => &value.envelope,
            Self::Range(value) => &value.envelope,
            Self::Link(value) => &value.envelope,
            Self::CellChange(value) => &value.envelope,
            Self::Sort(value) => &value.envelope,
            Self::Toggle(value) => &value.envelope,
            Self::Release(value) => &value.envelope,
        }
    }
}

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
