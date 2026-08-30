use std::sync::Arc;

use crate::host_contract::{ComponentEvent, ComponentEventSink};

#[derive(Clone)]
pub struct ComponentHost {
    events: Arc<dyn ComponentEventSink>,
}

impl ComponentHost {
    pub fn new(events: Arc<dyn ComponentEventSink>) -> Self {
        Self { events }
    }
    pub fn emit(&self, event: ComponentEvent) {
        self.events.emit(event);
    }
}
