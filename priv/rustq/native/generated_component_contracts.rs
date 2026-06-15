#[cfg(feature = "real-gpui")]
pub(crate) fn render_generated_text_component(text: String) -> gpui::AnyElement {
    render_generated_text_primitive(text)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_generated_image_component(
    raster: ImageData,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    render_generated_image_primitive(raster, runtime, window_id)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_generated_input_component(
    style: StyleAttrs,
    value: String,
    placeholder: Option<String>,
    change: Option<String>,
    keydown: Option<String>,
    keyup: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    render_generated_input_primitive(
        style,
        value,
        placeholder,
        change,
        keydown,
        keyup,
        runtime,
        window_id,
    )
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_generated_container_component(
    tag: GeneratedElementTag,
    style: StyleAttrs,
    children: Vec<ElementNode>,
    click: Option<String>,
    runtime: ResourceArc<RuntimeResource>,
    window_id: u64,
) -> gpui::AnyElement {
    render_generated_container_primitive(tag, style, children, click, runtime, window_id)
}
