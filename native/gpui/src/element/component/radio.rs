use crate::element::ElementRenderContext;
use crate::{gpui, RadioGroupComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(super) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };
    use gpui_component::{h_flex, radio::Radio, v_flex, Sizable};

    let size = node.size.clone();
    let selected = node.value.clone();
    let group_id = node.id.clone();
    let disabled = node.disabled;
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let radios = node.options.into_iter().map(|option| {
        let value = option.value;
        let checked = selected.as_ref() == Some(&value);
        let event = change_event.clone();
        let event_runtime = runtime.clone();
        let mut radio = Radio::new(format!("{group_id}-{value}"))
            .label(option.label)
            .checked(checked)
            .disabled(disabled || option.disabled)
            .on_click(move |new_checked, _window, _cx| {
                if !*new_checked {
                    return;
                }
                let Some(event) = event.as_ref() else {
                    return;
                };
                let _ = push_event(
                    &event_runtime,
                    NativeEvent::Input {
                        kind: InputKind::Change,
                        window_id,
                        event: event.clone(),
                        value: Some(EventValue::String(value.clone())),
                    },
                );
            });
        radio = match size.as_deref() {
            Some("xs") => radio.xsmall(),
            Some("sm") => radio.small(),
            Some("lg") => radio.large(),
            _ => radio,
        };
        radio
    });
    let group = if node.orientation.as_deref() == Some("horizontal") {
        h_flex().w_full().flex_wrap()
    } else {
        v_flex()
    }
    .gap_3()
    .children(radios);
    let element = crate::apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .role(Role::RadioGroup)
        .child(group);

    element.into_any_element()
}

#[cfg(not(feature = "components"))]
pub(super) fn render(
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
