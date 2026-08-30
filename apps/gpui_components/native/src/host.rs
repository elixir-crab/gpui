use std::sync::Arc;

use crate::host_contract::{ComponentEvent, ComponentEventError, ComponentEventSink};

pub struct ComponentHost {
    events: Arc<dyn ComponentEventSink>,
}

impl Clone for ComponentHost {
    fn clone(&self) -> Self {
        Self {
            events: self.events.clone(),
        }
    }
}

impl ComponentHost {
    pub fn new(events: Arc<dyn ComponentEventSink>) -> Self {
        Self { events }
    }
    pub fn emit(&self, event: ComponentEvent) -> Result<(), ComponentEventError> {
        self.events.emit(event)
    }
}
