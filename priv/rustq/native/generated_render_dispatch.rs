match node {
    ElementNode::Text(text) => render_generated_text_component(text),
    ElementNode::Image(raster) => render_generated_image_component(raster, runtime),
    ElementNode::Input {
        style,
        value,
        placeholder,
        change,
        keydown,
        keyup,
    } => render_generated_input_component(
        style,
        value,
        placeholder,
        change,
        keydown,
        keyup,
        runtime,
        window_id,
    ),
    ElementNode::Div {
        style,
        children,
        click,
    } => render_generated_container_component(style, children, click, runtime, window_id),
}
