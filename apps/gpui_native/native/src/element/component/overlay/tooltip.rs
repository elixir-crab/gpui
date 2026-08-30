use super::{invalid_slots, render_slot};
use crate::{gpui, ElementRenderContext, TooltipComponentNode, TooltipTriggerComponentNode};

#[cfg(feature = "components")]
pub(crate) fn render_tooltip(
    node: TooltipComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};
    use gpui_component::tooltip::Tooltip;
    use std::time::Duration;

    let trigger = match tooltip_trigger(node.children) {
        Some(trigger) => trigger,
        None => return invalid_slots(),
    };
    let text: gpui::SharedString = node.text.into();
    let tooltip_text = text.clone();
    let mut element = crate::apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .child(render_tooltip_trigger(trigger, context));
    element = if node.hoverable {
        element.hoverable_tooltip(move |window, cx| {
            Tooltip::new(tooltip_text.clone()).build(window, cx)
        })
    } else {
        element.tooltip(move |window, cx| Tooltip::new(text.clone()).build(window, cx))
    };

    let delay = if node.delay.is_finite() {
        node.delay.clamp(0.0, 60_000.0)
    } else {
        500.0
    };
    element
        .tooltip_show_delay(Duration::from_secs_f64(delay / 1000.0))
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_tooltip(
    node: TooltipComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    match tooltip_trigger(node.children) {
        Some(trigger) => render_tooltip_trigger(trigger, context),
        None => invalid_slots(),
    }
}

fn tooltip_trigger(children: Vec<crate::ElementNode>) -> Option<TooltipTriggerComponentNode> {
    let mut children = children.into_iter();
    match (children.next(), children.next()) {
        (Some(crate::ElementNode::TooltipTriggerComponent(trigger)), None) => Some(trigger),
        _other => None,
    }
}

pub(crate) fn render_tooltip_trigger(
    node: TooltipTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}
