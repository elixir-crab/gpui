use crate::element::ElementRenderContext;
use crate::gpui;

#[cfg(feature = "components")]
#[allow(dead_code)]
pub(crate) fn attach_rendered_control(
    rendered: gpui_components::rendered_control::RenderedControl,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};

    let accessibility = rendered.accessibility;
    let mut element = gpui::div()
        .id(format!("{}-component", rendered.test_id))
        .role(accessibility.role)
        .child(rendered.element);
    if let Some(label) = accessibility.label {
        element = element.aria_label(label);
    }
    if let Some(orientation) = accessibility.orientation {
        element = element.aria_orientation(orientation);
    }
    if let Some(toggled) = accessibility.toggled {
        element = element.aria_toggled(toggled);
    }
    let focus = rendered.primary_focus.clone();
    let element = if accessibility.disabled {
        element.tab_index(-1)
    } else {
        element
    };
    crate::element::register_test_target(element, rendered.test_id, focus, context)
        .into_any_element()
}
