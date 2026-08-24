use crate::*;

#[cfg(feature = "real-gpui")]
#[allow(clippy::too_many_arguments)]
pub(crate) fn apply_click_event(
    element: gpui::Div,
    element_id: String,
    event: Option<String>,
    accessibility: super::AccessibilitySemantics,
    runtime: SharedRuntime,
    window_id: u64,
    motion: super::ContainerMotion,
    window_control: Option<String>,
) -> gpui::AnyElement {
    use gpui::{AccessibleAction, InteractiveElement, StatefulInteractiveElement};

    let debug_selector = element_id.clone();
    let element_id = if event.is_some() {
        format!("gpui-elixir-click-{window_id}-{element_id}")
    } else {
        element_id
    };
    let element = element.debug_selector(|| debug_selector).id(element_id);
    let element = super::apply_window_control(element, window_control, runtime.clone(), window_id);

    if let Some(event) = event {
        let enabled = !accessibility.disabled;
        let activatable = enabled
            && accessibility
                .role
                .as_ref()
                .is_some_and(AccessibilityRole::is_activatable);
        let element = super::apply_accessibility_semantics(element, accessibility.clone());
        let element = if activatable {
            let keyboard_runtime = runtime.clone();
            let keyboard_event = event.clone();
            element
                .key_context("GPUIAccessibleControl")
                .tab_index(0)
                .focus_visible(|style| style.border_2().border_color(gpui::rgb(0x60a5fa)))
                .on_key_down(move |key, _window, cx| {
                    if matches!(key.keystroke.key.as_str(), "enter" | "space") {
                        emit_click_event(&keyboard_runtime, window_id, &keyboard_event);
                        cx.stop_propagation();
                    }
                })
        } else {
            element
        };
        let pointer_runtime = runtime.clone();
        let pointer_event = event.clone();

        let element = if enabled {
            element
                .on_click(move |_event, _window, _cx| {
                    emit_click_event(&pointer_runtime, window_id, &pointer_event);
                })
                .on_a11y_action(AccessibleAction::Click, move |_data, _window, _cx| {
                    emit_click_event(&runtime, window_id, &event);
                })
        } else {
            element
        };

        let actions = if enabled {
            vec![AccessibleAction::Click]
        } else {
            vec![]
        };
        super::apply_container_motion(element, motion, accessibility, actions)
    } else {
        super::apply_container_motion(element, motion, accessibility, vec![])
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
    use crate::{event::NativeEvent, runtime::RuntimeState, AccessibilityRole};
    use std::sync::Arc;

    #[test]
    fn generated_role_policy_only_tab_stops_simple_activation_controls() {
        for role in [
            AccessibilityRole::Button,
            AccessibilityRole::Checkbox,
            AccessibilityRole::Link,
            AccessibilityRole::Radio,
            AccessibilityRole::Switch,
        ] {
            assert!(role.is_activatable());
        }

        for role in [
            AccessibilityRole::Group,
            AccessibilityRole::List,
            AccessibilityRole::TabList,
            AccessibilityRole::Tree,
            AccessibilityRole::Slider,
        ] {
            assert!(!role.is_activatable());
        }
    }

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
