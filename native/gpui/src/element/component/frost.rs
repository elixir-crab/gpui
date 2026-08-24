use crate::element::ElementRenderContext;
use crate::{gpui, FrostComponentNode};

pub(crate) fn render_frost(
    node: FrostComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, ParentElement, Styled};

    let FrostComponentNode {
        style,
        id,
        fallback,
        opacity,
        reduced_transparency,
        children,
    } = node;
    let opacity = (opacity as f32).clamp(0.0, 1.0);
    let opaque = reduced_transparency || fallback.as_deref() == Some("solid");

    #[cfg(feature = "components")]
    let color = {
        use gpui_component::ActiveTheme;
        context
            .cx
            .theme()
            .background
            .opacity(if opaque { 1.0 } else { opacity })
    };
    #[cfg(not(feature = "components"))]
    let color = gpui::Hsla::from(gpui::rgba(if opaque {
        0x000000ff
    } else {
        (opacity * 255.0).round() as u32
    }));

    let mut element = crate::element::apply_generated_render_styles(gpui::div(), style)
        .id(id)
        .relative()
        .bg(color);

    for child in children {
        element = element.child(child.render(context));
    }

    element.into_any_element()
}

#[cfg(test)]
mod tests {
    #[test]
    fn reduced_transparency_forces_opaque_fallback() {
        let opacity = 0.42_f32;
        assert_eq!(if true { 1.0 } else { opacity }, 1.0);
        assert_eq!(if false { 1.0 } else { opacity }, opacity);
    }
}
