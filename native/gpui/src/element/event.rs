use crate::*;

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_click_event(
    element: gpui::Div,
    event: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, StatefulInteractiveElement};

    if let Some(event) = event {
        let runtime_for_click = runtime.clone();
        let element_id = format!("gpui-elixir-click-{window_id}-{event}");

        element
            .id(element_id)
            .on_click(move |_event, _window, _cx| {
                let _ = push_event(
                    &runtime_for_click,
                    NativeEvent::Click {
                        window_id,
                        event: event.clone(),
                    },
                );
            })
            .into_any_element()
    } else {
        element.into_any_element()
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_input_events(
    element: gpui::Div,
    value: String,
    change: Option<String>,
    keydown: Option<String>,
    keyup: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, StatefulInteractiveElement};

    let input_id = format!(
        "gpui-elixir-input-{window_id}-{}",
        change.clone().unwrap_or_default()
    );
    initialize_input_value(&runtime, &input_id, &value);

    let mut element = element
        .key_context("GPUIInput")
        .tab_index(0)
        .id(input_id.clone());
    let change_for_keys = change.clone();

    if let Some(event) = change {
        let runtime_for_change = runtime.clone();
        let input_id_for_change = input_id.clone();
        element = element.on_click(move |_event, _window, _cx| {
            let _ = push_event(
                &runtime_for_change,
                NativeEvent::Input {
                    kind: "change".to_string(),
                    window_id,
                    event: event.clone(),
                    value: input_value(&runtime_for_change, &input_id_for_change),
                },
            );
        });
    }

    if let Some(event) = keydown {
        let runtime_for_keydown = runtime.clone();
        let runtime_for_change = runtime.clone();
        let input_id_for_keydown = input_id.clone();
        let change_for_keydown = change_for_keys.clone();
        element = element.on_key_down(move |key_event, _window, _cx| {
            let key_value = key_event
                .keystroke
                .key_char
                .clone()
                .or_else(|| Some(key_event.keystroke.key.clone()));

            if let Some(updated_value) = mutate_input_value(
                &runtime_for_change,
                &input_id_for_keydown,
                &key_event.keystroke,
            ) {
                if let Some(change_event) = change_for_keydown.as_ref() {
                    let _ = push_event(
                        &runtime_for_change,
                        NativeEvent::Input {
                            kind: "change".to_string(),
                            window_id,
                            event: change_event.clone(),
                            value: Some(updated_value),
                        },
                    );
                }
            }

            let _ = push_event(
                &runtime_for_keydown,
                NativeEvent::Input {
                    kind: "keydown".to_string(),
                    window_id,
                    event: event.clone(),
                    value: key_value,
                },
            );
        });
    }

    if let Some(event) = keyup {
        let runtime_for_keyup = runtime.clone();
        element = element.on_key_up(move |key_event, _window, _cx| {
            let value = key_event
                .keystroke
                .key_char
                .clone()
                .or_else(|| Some(key_event.keystroke.key.clone()));
            let _ = push_event(
                &runtime_for_keyup,
                NativeEvent::Input {
                    kind: "keyup".to_string(),
                    window_id,
                    event: event.clone(),
                    value,
                },
            );
        });
    }

    element.into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn initialize_input_value(
    runtime: &ResourceArc<RuntimeResource>,
    input_id: &str,
    value: &str,
) {
    if let Ok(mut values) = runtime.input_values.lock() {
        values
            .entry(input_id.to_string())
            .or_insert_with(|| value.to_string());
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn input_value(
    runtime: &ResourceArc<RuntimeResource>,
    input_id: &str,
) -> Option<String> {
    runtime
        .input_values
        .lock()
        .ok()
        .and_then(|values| values.get(input_id).cloned())
}

#[cfg(feature = "real-gpui")]
pub(crate) fn mutate_input_value(
    runtime: &ResourceArc<RuntimeResource>,
    input_id: &str,
    keystroke: &gpui::Keystroke,
) -> Option<String> {
    let mut values = runtime.input_values.lock().ok()?;
    let value = values.entry(input_id.to_string()).or_default();

    match keystroke.key.as_str() {
        "backspace" | "Backspace" => {
            value.pop()?;
            Some(value.clone())
        }
        "delete" | "Delete" => Some(value.clone()),
        _ => {
            let key_char = keystroke.key_char.as_deref()?;
            if key_char.chars().any(|character| character.is_control()) {
                return None;
            }
            value.push_str(key_char);
            Some(value.clone())
        }
    }
}
