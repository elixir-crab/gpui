use crate::element::ElementRenderContext;
use crate::{gpui, EdgeFadeComponentNode};

const MAX_EDGE_FADE_SIZE: f32 = 256.0;

pub(crate) fn render_edge_fade(
    node: EdgeFadeComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        div, linear_color_stop, linear_gradient, prelude::FluentBuilder, InteractiveElement,
        IntoElement, ParentElement, Styled,
    };
    #[cfg(feature = "components")]
    use gpui_component::ActiveTheme;

    let EdgeFadeComponentNode {
        style,
        id,
        edges,
        size,
        opacity,
        children,
    } = node;
    let size = (size as f32).clamp(1.0, MAX_EDGE_FADE_SIZE);
    #[cfg(feature = "components")]
    let opacity = (opacity as f32).clamp(0.0, 1.0);
    #[cfg(not(feature = "components"))]
    let _opacity = opacity;
    #[cfg(feature = "components")]
    let color = context.cx.theme().background.opacity(opacity);
    #[cfg(not(feature = "components"))]
    let color: gpui::Hsla = gpui::rgba(0x000000ff).into();
    let transparent = color.opacity(0.0);
    let mut element = crate::element::apply_generated_render_styles(div(), style)
        .id(id)
        .relative()
        .overflow_hidden();

    for child in children {
        element = element.child(child.render(context));
    }

    for edge in edges {
        let angle = match edge.as_str() {
            "top" => 180.0,
            "right" => 270.0,
            "bottom" => 0.0,
            "left" => 90.0,
            _ => continue,
        };
        let fade = div()
            .absolute()
            .when(edge == "top", |fade| {
                fade.top_0().left_0().right_0().h(gpui::px(size))
            })
            .when(edge == "right", |fade| {
                fade.top_0().right_0().bottom_0().w(gpui::px(size))
            })
            .when(edge == "bottom", |fade| {
                fade.bottom_0().left_0().right_0().h(gpui::px(size))
            })
            .when(edge == "left", |fade| {
                fade.top_0().bottom_0().left_0().w(gpui::px(size))
            })
            .bg(linear_gradient(
                angle,
                linear_color_stop(color, 0.0),
                linear_color_stop(transparent, 1.0),
            ));
        element = element.child(fade);
    }

    element.into_any_element()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn edge_fade_size_is_bounded() {
        assert_eq!((-10.0_f32).clamp(1.0, MAX_EDGE_FADE_SIZE), 1.0);
        assert_eq!(900.0_f32.clamp(1.0, MAX_EDGE_FADE_SIZE), 256.0);
    }
}
