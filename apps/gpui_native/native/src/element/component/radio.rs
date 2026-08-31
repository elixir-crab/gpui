use crate::element::ElementRenderContext;
use crate::{gpui, RadioGroupComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let owner = crate::radio_group_to_owner(node);
    let rendered = gpui_components::radio::render(
        owner,
        &mut gpui_components::radio::RadioContext {
            window_id: context.window_id,
            host: context.runtime.component_host().clone(),
            window: context.window,
            cx: context.cx,
        },
    );
    crate::rendered_control::attach_rendered_control(rendered, context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.label), Vec::new(), context)
}
