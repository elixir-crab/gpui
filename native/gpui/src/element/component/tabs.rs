use crate::element::ElementRenderContext;
use crate::{gpui, TabsComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(super) fn render(
    node: TabsComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::IntoElement;
    use gpui_component::{
        tab::{Tab, TabBar},
        Sizable,
    };

    let selected_index = node.value.as_ref().and_then(|value| {
        node.options
            .iter()
            .position(|option| &option.value == value)
    });
    let tabs = node
        .options
        .iter()
        .map(|option| {
            Tab::new()
                .label(option.label.clone())
                .disabled(node.disabled)
        })
        .collect::<Vec<_>>();
    let values = node
        .options
        .iter()
        .map(|option| option.value.clone())
        .collect::<Vec<_>>();
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let mut element = TabBar::new(node.id)
        .children(tabs)
        .menu(node.menu)
        .on_click(move |index, _window, _cx| {
            let Some(event) = change_event.as_ref() else {
                return;
            };
            let Some(value) = values.get(*index) else {
                return;
            };
            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::Change,
                    window_id,
                    event: event.clone(),
                    value: Some(EventValue::String(value.clone())),
                },
            );
        });
    if let Some(selected_index) = selected_index {
        element = element.selected_index(selected_index);
    }
    element = match node.variant.as_deref() {
        Some("outline") => element.outline(),
        Some("pill") => element.pill(),
        Some("segmented") => element.segmented(),
        Some("underline") => element.underline(),
        _ => element,
    };
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
    node: TabsComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let label = node
        .value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone());

    render_component_fallback(node.style, label, Vec::new(), context)
}
