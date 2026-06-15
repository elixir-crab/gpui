#[cfg(feature = "real-gpui")]
pub(crate) fn apply_generated_click_event(
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
pub(crate) fn apply_generated_input_events(
    element: gpui::Div,
    value: String,
    change: Option<String>,
    keydown: Option<String>,
    keyup: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, StatefulInteractiveElement};

    let mut element = element
        .key_context("GPUIInput")
        .tab_index(0)
        .id(format!(
            "gpui-elixir-input-{window_id}-{}",
            change.clone().unwrap_or_default()
        ));
    let local_value = std::sync::Arc::new(std::sync::Mutex::new(value.clone()));
    let change_for_keys = change.clone();

    if let Some(event) = change {
        let runtime_for_change = runtime.clone();
        let value_for_change = value.clone();
        element = element.on_click(move |_event, _window, _cx| {
            let _ = push_event(
                &runtime_for_change,
                NativeEvent::Input {
                    kind: "change".to_string(),
                    window_id,
                    event: event.clone(),
                    value: Some(value_for_change.clone()),
                },
            );
        });
    }

    if let Some(event) = keydown {
        let runtime_for_keydown = runtime.clone();
        let runtime_for_change = runtime.clone();
        let local_value_for_keydown = local_value.clone();
        let change_for_keydown = change_for_keys.clone();
        element = element.on_key_down(move |key_event, _window, _cx| {
            let key_value = key_event
                .keystroke
                .key_char
                .clone()
                .or_else(|| Some(key_event.keystroke.key.clone()));

            if let Some(updated_value) =
                mutate_generated_input_value(&local_value_for_keydown, &key_event.keystroke)
            {
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
pub(crate) fn mutate_generated_input_value(
    value: &std::sync::Arc<std::sync::Mutex<String>>,
    keystroke: &gpui::Keystroke,
) -> Option<String> {
    let mut value = value.lock().ok()?;

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
