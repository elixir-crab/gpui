use crate::element::ElementRenderContext;
use crate::{gpui, PaintComponentNode};

pub(crate) fn render_paint(
    node: PaintComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        canvas, fill, point, px, Bounds, InteractiveElement, IntoElement, ParentElement,
        PathBuilder, Styled,
    };

    let canvas = canvas(
        move |_, _, _| {},
        move |bounds, _, window, _| {
            for command in &node.commands {
                match command.kind.as_str() {
                    "rect" => window.paint_quad(fill(
                        Bounds::new(
                            point(
                                bounds.origin.x + px(command.x as f32),
                                bounds.origin.y + px(command.y as f32),
                            ),
                            gpui::size(px(command.width as f32), px(command.height as f32)),
                        ),
                        gpui::rgba(command.color),
                    )),
                    "line" => {
                        let mut path = PathBuilder::stroke(px(command.width as f32));
                        path.move_to(point(
                            bounds.origin.x + px(command.x as f32),
                            bounds.origin.y + px(command.y as f32),
                        ));
                        path.line_to(point(
                            bounds.origin.x + px(command.x2 as f32),
                            bounds.origin.y + px(command.y2 as f32),
                        ));
                        if let Ok(path) = path.build() {
                            window.paint_path(path, gpui::rgba(command.color));
                        }
                    }
                    _ => {}
                }
            }
        },
    )
    .size_full();

    crate::element::apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .child(canvas)
        .into_any_element()
}
