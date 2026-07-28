pub(crate) mod accordion;
pub(crate) mod code_viewer;
pub(crate) mod controls;
pub(crate) mod data_table;
pub(crate) mod display;
pub(crate) mod form;
pub(crate) mod overlay;
pub(crate) mod radio;
pub(crate) mod slider;
pub(crate) mod switch;
pub(crate) mod tabs;
pub(crate) mod text_surface;
pub(crate) mod tree;
pub(crate) mod uniform_collection;
pub(crate) mod virtual_list;

use super::apply_generated_render_styles;
#[cfg(not(feature = "components"))]
use super::ElementRenderContext;
use crate::gpui;
#[cfg(feature = "components")]
use crate::gpui::Styled;

#[cfg(feature = "components")]
fn component_input_height(size: Option<&str>, styled_height: Option<gpui::DefiniteLength>) -> f32 {
    let styled_height = styled_height.and_then(|height| match height {
        gpui::DefiniteLength::Absolute(gpui::AbsoluteLength::Pixels(height)) => {
            Some(f32::from(height))
        }
        _ => None,
    });

    styled_height.unwrap_or(match size {
        Some("xs") => 20.0,
        Some("sm") => 24.0,
        Some("lg") => 44.0,
        _ => 32.0,
    })
}

#[cfg(feature = "components")]
pub(super) fn constrain_full_size_component(
    component: impl gpui::IntoElement,
    height: f32,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement, Styled};

    gpui::div()
        .flex()
        .h(gpui::px(height))
        .child(component)
        .into_any_element()
}

#[cfg(feature = "components")]
pub(super) fn apply_component_styles<T>(mut component: T, style: crate::StyleAttrs) -> T
where
    T: gpui::Styled,
{
    use gpui::Refineable;

    let mut refinement = apply_generated_render_styles(gpui::div(), style);
    component.style().refine(refinement.style());
    component
}

#[cfg(not(feature = "components"))]
pub(super) fn render_component_fallback(
    style: crate::StyleAttrs,
    label: Option<String>,
    children: Vec<super::ElementNode>,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    let mut element = apply_generated_render_styles(gpui::div(), style);
    if let Some(label) = label {
        element = element.child(label);
    }
    for child in children {
        element = element.child(child.render(context));
    }
    element.into_any_element()
}
