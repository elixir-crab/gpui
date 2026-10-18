use crate::{gpui, DragSourceComponentNode, ElementRenderContext};

/// The value an in-app drag carries to drop targets that accept values.
#[derive(Clone, Debug)]
pub(crate) struct DraggedValue {
    pub(crate) value: String,
}

/// Nothing follows the pointer: the application draws its own feedback
/// from the drop target's move events.
#[cfg(feature = "components")]
struct DragPreview;

#[cfg(feature = "components")]
impl gpui::Render for DragPreview {
    fn render(
        &mut self,
        _window: &mut gpui::Window,
        _cx: &mut gpui::Context<Self>,
    ) -> impl gpui::IntoElement {
        gpui::div()
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: DragSourceComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        AppContext, InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement,
    };

    let children = node
        .children
        .into_iter()
        .map(|child| child.render(context))
        .collect::<Vec<_>>();
    let value = DraggedValue { value: node.value };

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .children(children)
        .on_drag(value, |_value, _offset, _window, cx| {
            cx.new(|_| DragPreview)
        })
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: DragSourceComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    super::render_component_fallback(node.style, None, node.children, context)
}
