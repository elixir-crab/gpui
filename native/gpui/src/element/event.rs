use crate::*;

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_click_event(
    element: gpui::Div,
    element_id: usize,
    event: Option<String>,
    runtime: SharedRuntime,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, StatefulInteractiveElement};

    if let Some(event) = event {
        let element_id = format!("gpui-elixir-click-{window_id}-{element_id}");

        element
            .id(element_id)
            .on_click(move |_event, _window, _cx| {
                let _ = push_event(
                    &runtime,
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
                .or_else(|| Some(key_event.keystroke.key.clone()));

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
                .or_else(|| Some(key_event.keystroke.key.clone()));

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
