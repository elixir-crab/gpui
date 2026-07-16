use crate::element::ElementRenderContext;
use crate::{gpui, SwitchComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(super) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::IntoElement;
    use gpui_component::{switch::Switch, Disableable, Sizable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let mut element = Switch::new(node.id)
        .checked(node.checked)
        .disabled(node.disabled || node.loading)
        .on_click(move |checked, _window, _cx| {
            let Some(event) = change_event.as_ref() else {
                return;
            };
            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::Change,
                    window_id,
                    event: event.clone(),
                    value: Some(EventValue::Boolean(*checked)),
                },
            );
        });
    if let Some(label) = node.label {
        element = element.label(label);
    }
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };

    apply_component_styles(element, node.style).into_any_element()
}

#[cfg(not(feature = "components"))]
pub(super) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, Vec::new(), context)
}
