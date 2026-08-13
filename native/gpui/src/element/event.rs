use crate::*;

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_click_event(
    element: gpui::Div,
    element_id: String,
    event: Option<String>,
    accessibility: super::AccessibilitySemantics,
    runtime: SharedRuntime,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{AccessibleAction, InteractiveElement, IntoElement, StatefulInteractiveElement};

    if let Some(event) = event {
        let element_id = format!("gpui-elixir-click-{window_id}-{element_id}");

        let element = element.id(element_id);
        let element = super::apply_accessibility_semantics(element, accessibility);
        let pointer_runtime = runtime.clone();
        let pointer_event = event.clone();

        element
            .on_click(move |_event, _window, _cx| {
                emit_click_event(&pointer_runtime, window_id, &pointer_event);
            })
            .on_a11y_action(AccessibleAction::Click, move |_data, _window, _cx| {
                emit_click_event(&runtime, window_id, &event);
            })
            .into_any_element()
    } else if accessibility.role.is_some() {
        super::apply_accessibility_semantics(element.id(element_id), accessibility)
            .into_any_element()
    } else {
        element.into_any_element()
    }
}

#[cfg(feature = "real-gpui")]
fn emit_click_event(runtime: &SharedRuntime, window_id: u64, event: &str) {
    let _ = push_event(
        runtime,
        NativeEvent::Click {
            window_id,
            event: event.to_string(),
        },
    );
}

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_input_events(
    element: gpui::Div,
    input_id: String,
    keydown: Option<String>,
    keyup: Option<String>,
    runtime: SharedRuntime,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement};

    let mut element = element.key_context("GPUIInput").tab_index(0).id(input_id);

    if let Some(event) = keydown {
        let runtime = runtime.clone();
        element = element.on_key_down(move |key_event, _window, _cx| {
            let value = key_event
                .keystroke
                .key_char
                .clone()
                .or_else(|| Some(key_event.keystroke.key.clone()))
                .map(EventValue::String);

            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::KeyDown,
                    window_id,
                    event: event.clone(),
                    value,
                },
            );
        });
    }

    if let Some(event) = keyup {
        element = element.on_key_up(move |key_event, _window, _cx| {
            let value = key_event
                .keystroke
                .key_char
                .clone()
                .or_else(|| Some(key_event.keystroke.key.clone()))
                .map(EventValue::String);

            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::KeyUp,
                    window_id,
                    event: event.clone(),
                    value,
                },
            );
        });
    }

    element.into_any_element()
}

#[cfg(all(test, feature = "real-gpui"))]
mod tests {
    use super::emit_click_event;
    use crate::{event::NativeEvent, runtime::RuntimeState};
    use std::sync::Arc;

    #[test]
    fn pointer_and_accessible_activation_share_the_same_native_event_path() {
        let runtime = Arc::new(RuntimeState::new());

        emit_click_event(&runtime, 7, "toggle");
        emit_click_event(&runtime, 7, "toggle");

        let events = runtime.events.lock().expect("event queue");
        assert_eq!(events.len(), 2);
        for event in events.iter() {
            assert!(matches!(
                event,
                NativeEvent::Click { window_id: 7, event } if event == "toggle"
            ));
        }
    }
}
