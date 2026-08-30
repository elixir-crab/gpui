use crate::host::ComponentHost;
use crate::host_contract::{
    ComponentEvent, ComponentEventEnvelope, ComponentValue, ComponentValueEvent,
};

pub fn emit_string_change(
    host: &ComponentHost,
    window_id: u64,
    event: Option<&String>,
    value: &str,
) {
    let Some(event) = event else {
        return;
    };
    let _ = host.emit(ComponentEvent::Change(ComponentValueEvent {
        envelope: ComponentEventEnvelope {
            window_id,
            event: event.clone(),
        },
        value: ComponentValue::String(value.to_owned()),
    }));
}

pub fn tab_key_target(key: &str, current: usize, len: usize) -> Option<usize> {
    if len == 0 {
        return None;
    }
    match key {
        "left" | "up" => Some((current + len - 1) % len),
        "right" | "down" => Some((current + 1) % len),
        "home" => Some(0),
        "end" => Some(len - 1),
        "enter" | "space" => Some(current),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keyboard_navigation_wraps_and_supports_endpoints() {
        assert_eq!(tab_key_target("left", 0, 3), Some(2));
        assert_eq!(tab_key_target("right", 2, 3), Some(0));
        assert_eq!(tab_key_target("home", 2, 3), Some(0));
        assert_eq!(tab_key_target("end", 0, 3), Some(2));
    }
}
