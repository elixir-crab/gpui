use crate::element::ElementRenderContext;
use crate::{gpui, SliderComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: SliderComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement, Styled,
    };

    let owner = crate::slider_to_owner(node);
    let vertical = owner.orientation.as_deref() == Some("vertical");
    let config = gpui_components::slider::config(&owner);
    if !config.accepts(owner.value as f32) {
        return gpui_core::style::apply(gpui::div(), owner.style).into_any_element();
    }
    let rebuild = context
        .components
        .slider_mut(&owner.id)
        .map(|slider| slider.config != config)
        .unwrap_or(true);
    if rebuild {
        let slider = gpui_components::slider::create(
            &owner,
            context.runtime.component_host().clone(),
            context.window_id,
            context.window,
            context.cx,
        );
        context.components.insert_slider(&owner.id, slider);
    }
    let accessibility_id = owner.id.clone();
    let label = owner.label.clone();
    let height = gpui_components::slider::height(&owner);
    let slider = context
        .components
        .slider_mut(&owner.id)
        .expect("component slider should exist");
    let element = gpui_components::slider::render(&owner, slider, context.window, context.cx);
    gpui::div()
        .id(format!("slider-accessibility-{accessibility_id}"))
        .role(gpui::Role::Group)
        .aria_label(label)
        .aria_orientation(if vertical {
            gpui::Orientation::Vertical
        } else {
            gpui::Orientation::Horizontal
        })
        .w_full()
        .h(gpui::px(height))
        .child(element)
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: SliderComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(
        node.style,
        Some(node.value.to_string()),
        Vec::new(),
        context,
    )
}
