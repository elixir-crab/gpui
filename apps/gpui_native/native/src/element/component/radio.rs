use crate::element::ElementRenderContext;
use crate::{gpui, RadioGroupComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
#[derive(Debug, PartialEq)]
struct RadioGroupAccessibility {
    label: String,
    orientation: gpui::Orientation,
}

#[cfg(feature = "components")]
fn radio_group_accessibility(label: String, orientation: Option<&str>) -> RadioGroupAccessibility {
    RadioGroupAccessibility {
        label,
        orientation: if orientation == Some("horizontal") {
            gpui::Orientation::Horizontal
        } else {
            gpui::Orientation::Vertical
        },
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };
    use gpui_component::{h_flex, radio::Radio, v_flex, Sizable};

    let size = node.size.clone();
    let selected = node.value.clone();
    let accessibility = radio_group_accessibility(node.label.clone(), node.orientation.as_deref());
    let horizontal = accessibility.orientation == gpui::Orientation::Horizontal;
    let group_id = node.id.clone();
    let disabled = node.disabled;
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let key_options = node
        .options
        .iter()
        .map(|option| {
            (
                option.value.clone(),
                format!("{group_id}-{}", option.value),
                disabled || option.disabled,
            )
        })
        .collect::<Vec<_>>();
    let focus_handles = key_options
        .iter()
        .map(|(_value, id, _disabled)| {
            context
                .window
                .use_keyed_state(id.clone(), context.cx, |_, cx| cx.focus_handle())
                .read(context.cx)
                .clone()
        })
        .collect::<Vec<_>>();
    let selected_index = key_options
        .iter()
        .position(|(value, _id, _disabled)| Some(value) == selected.as_ref());
    let tab_index = selected_index
        .filter(|index| !key_options[*index].2)
        .or_else(|| {
            key_options
                .iter()
                .position(|(_value, _id, disabled)| !disabled)
        });

    let radios = node.options.into_iter().enumerate().map(|(index, option)| {
        let value = option.value;
        let checked = selected.as_ref() == Some(&value);
        let option_disabled = disabled || option.disabled;
        let event = change_event.clone();
        let event_runtime = runtime.clone();
        let mut radio = Radio::new(format!("{group_id}-{value}"))
            .label(option.label)
            .checked(checked)
            .disabled(option_disabled)
            .tab_stop(tab_index == Some(index))
            .tab_index(if tab_index == Some(index) { 0 } else { -1 })
            .on_click(move |new_checked, _window, _cx| {
                if *new_checked {
                    emit_change(&event_runtime, window_id, event.as_ref(), &value);
                }
            });
        radio = match size.as_deref() {
            Some("xs") => radio.xsmall(),
            Some("sm") => radio.small(),
            Some("lg") => radio.large(),
            _ => radio,
        };
        radio
    });
    let group = if horizontal {
        h_flex().w_full().flex_wrap()
    } else {
        v_flex()
    }
    .gap_3()
    .children(radios);
    let key_runtime = runtime.clone();
    let key_event = change_event.clone();
    let key_focus_handles = focus_handles.clone();
    let element = crate::apply_generated_render_styles(gpui::div(), node.style).id(node.id);
    let element = crate::element::register_test_target(
        element,
        group_id,
        tab_index.and_then(|index| focus_handles.get(index).cloned()),
        context,
    );
    let element = element
        .role(Role::RadioGroup)
        .aria_label(accessibility.label)
        .aria_orientation(accessibility.orientation)
        .on_key_down(move |event, window, cx| {
            let focused_index = key_focus_handles
                .iter()
                .position(|handle| handle.is_focused(window));
            let current = focused_index.or(selected_index).or(tab_index);
            let target = match event.keystroke.key.as_str() {
                "left" | "up" => previous_enabled(&key_options, current),
                "right" | "down" => next_enabled(&key_options, current),
                "enter" | "space" => current.filter(|index| !key_options[*index].2),
                _other => None,
            };
            let Some(target) = target else {
                return;
            };
            let (value, _id, _disabled) = &key_options[target];
            key_focus_handles[target].focus(window, cx);
            emit_change(&key_runtime, window_id, key_event.as_ref(), value);
            cx.stop_propagation();
        })
        .child(group);

    element.into_any_element()
}

#[cfg(feature = "components")]
fn next_enabled(options: &[(String, String, bool)], current: Option<usize>) -> Option<usize> {
    enabled_from(
        options,
        current.unwrap_or(options.len().saturating_sub(1)),
        1,
    )
}

#[cfg(feature = "components")]
fn previous_enabled(options: &[(String, String, bool)], current: Option<usize>) -> Option<usize> {
    enabled_from(
        options,
        current.unwrap_or(0),
        options.len().saturating_sub(1),
    )
}

#[cfg(feature = "components")]
fn enabled_from(
    options: &[(String, String, bool)],
    current: usize,
    increment: usize,
) -> Option<usize> {
    if options.is_empty() {
        return None;
    }

    (1..=options.len())
        .map(|offset| (current + offset * increment) % options.len())
        .find(|index| !options[*index].2)
}

#[cfg(feature = "components")]
fn emit_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&String>,
    value: &str,
) {
    let Some(event) = event else {
        return;
    };
    let _ = runtime
        .component_host()
        .emit(gpui_components::host_contract::ComponentEvent::Change(
            gpui_components::host_contract::ComponentValueEvent {
                envelope: gpui_components::host_contract::ComponentEventEnvelope {
                    window_id,
                    event: event.clone(),
                },
                value: gpui_components::host_contract::ComponentValue::String(value.to_string()),
            },
        ));
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::{radio_group_accessibility, RadioGroupAccessibility};

    #[test]
    fn accessibility_tracks_label_and_orientation() {
        assert_eq!(
            radio_group_accessibility("Plan".to_string(), Some("horizontal")),
            RadioGroupAccessibility {
                label: "Plan".to_string(),
                orientation: crate::gpui::Orientation::Horizontal,
            }
        );
        assert_eq!(
            radio_group_accessibility("Priority".to_string(), None),
            RadioGroupAccessibility {
                label: "Priority".to_string(),
                orientation: crate::gpui::Orientation::Vertical,
            }
        );
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let label = node
        .value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone());

    render_component_fallback(node.style, label, Vec::new(), context)
}
