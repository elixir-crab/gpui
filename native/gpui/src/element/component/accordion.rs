#[cfg(feature = "components")]
use crate::element::ElementNode;
use crate::element::ElementRenderContext;
use crate::{gpui, AccordionComponentNode, AccordionItemComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: AccordionComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{InteractiveElement, IntoElement, ParentElement};
    use gpui_component::{accordion::Accordion, Sizable};
    use std::collections::HashSet;

    let accordion_id = node.id.clone();
    let expanded = node.expanded.iter().collect::<HashSet<_>>();
    let mut item_ids = Vec::new();
    let mut items = Vec::new();
    for child in node.children {
        let ElementNode::AccordionItemComponent(item) = child else {
            continue;
        };
        let item_id = item.id;
        let is_open = expanded.contains(&item_id);
        let item_disabled = item.disabled || node.disabled;
        let title = crate::element::register_test_target(
            gpui::div()
                .id(format!("{item_id}-test-target"))
                .child(item.title.unwrap_or_default()),
            item_id.clone(),
            None,
            context,
        );
        let children = item
            .children
            .into_iter()
            .map(|child| child.render(context))
            .collect::<Vec<_>>();
        item_ids.push(item_id);
        items.push((title, item_disabled, is_open, children));
    }

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let disabled = node.disabled;
    let mut element = Accordion::new(node.id)
        .multiple(node.multiple)
        .bordered(node.bordered)
        .on_toggle_click(move |indices, _window, _cx| {
            if disabled {
                return;
            }
            let Some(event) = change_event.as_ref() else {
                return;
            };
            let mut indices = indices.to_vec();
            indices.sort_unstable();
            let values = indices
                .into_iter()
                .filter_map(|index| item_ids.get(index).cloned())
                .collect::<Vec<_>>();
            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::Change,
                    window_id,
                    event: event.clone(),
                    value: Some(EventValue::Strings(values)),
                },
            );
        });
    for (title, disabled, open, children) in items {
        element = element.item(move |item| {
            item.title(title)
                .disabled(disabled)
                .open(open)
                .children(children)
        });
    }
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };

    let element = crate::apply_generated_render_styles(gpui::div(), node.style)
        .id(format!("{accordion_id}-test-target"))
        .child(element);
    crate::element::register_test_target(element, accordion_id, None, context).into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_item(
    node: AccordionItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    let mut element = apply_component_styles(gpui::div(), node.style);
    if let Some(title) = node.title {
        element = element.child(title);
    }
    for child in node.children {
        element = element.child(child.render(context));
    }
    element.into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: AccordionComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, None, node.children, context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_item(
    node: AccordionItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.title, node.children, context)
}
