use crate::*;

pub(crate) mod event;

use event::{apply_click_event, apply_input_events};

#[cfg(feature = "real-gpui")]
#[derive(Clone, Debug)]
pub(crate) enum ElementNode {
    Div {
        tag: GeneratedElementTag,
        style: StyleAttrs,
        children: Vec<ElementNode>,
        click: Option<String>,
    },
    Input {
        style: StyleAttrs,
        value: String,
        placeholder: Option<String>,
        change: Option<String>,
        keydown: Option<String>,
        keyup: Option<String>,
    },
    Image {
        image: ImageData,
        style: StyleAttrs,
    },
    Text {
        text: String,
        style: StyleAttrs,
    },
}

#[cfg(feature = "real-gpui")]
pub(crate) struct ElementRenderContext<'a, 'cx> {
    pub(crate) runtime: SharedRuntime,
    pub(crate) window_id: u64,
    pub(crate) input_entities: &'a mut HashMap<String, gpui::Entity<NativeTextInput>>,
    pub(crate) cx: &'a mut gpui::Context<'cx, ElixirRoot>,
}

#[cfg(feature = "real-gpui")]
impl ElementNode {
    pub(crate) fn empty_root() -> Self {
        Self::Div {
            tag: GeneratedElementTag::Div,
            style: StyleAttrs::default(),
            children: Vec::new(),
            click: None,
        }
    }

    pub(crate) fn render(self, context: &mut ElementRenderContext<'_, '_>) -> gpui::AnyElement {
        match self {
            Self::Text { text, style } => render_text_primitive(text, style),
            Self::Image { image, style } => {
                render_image_primitive(image, style, context.runtime.clone(), context.window_id)
            }
            Self::Input {
                style,
                value,
                placeholder,
                change,
                keydown,
                keyup,
            } => render_input_primitive(style, value, placeholder, change, keydown, keyup, context),
            Self::Div {
                tag,
                style,
                children,
                click,
            } => render_container_primitive(tag, style, children, click, context),
        }
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_text_primitive(text: String, style: StyleAttrs) -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement};

    apply_generated_render_styles(div(), style)
        .child(text)
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_image_primitive(
    image: ImageData,
    style: StyleAttrs,
    runtime: SharedRuntime,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement};

    let image = match image {
        ImageData::Raster(raster) => raster.render(),
        ImageData::Ref(resource_id) => {
            if let Some(raster) = runtime
                .resources
                .lock()
                .ok()
                .and_then(|resources| resources.get(&resource_id).cloned())
            {
                raster.render()
            } else {
                let _ = push_event(
                    &runtime,
                    NativeEvent::MissingResource {
                        window_id,
                        id: resource_id,
                        resource_type: "raster".to_string(),
                    },
                );
                render_missing_resource_placeholder()
            }
        }
    };

    apply_generated_render_styles(div(), style)
        .child(image)
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_missing_resource_placeholder() -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement, Styled};

    div()
        .flex()
        .items_center()
        .justify_center()
        .border(gpui::px(1.0))
        .border_color(gpui::rgb(0xcc3333))
        .bg(gpui::rgb(0x332222))
        .text_color(gpui::rgb(0xffaaaa))
        .p(gpui::px(8.0))
        .child("missing resource")
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_container_semantics(element: gpui::Div, tag: GeneratedElementTag) -> gpui::Div {
    use gpui::Styled;

    match tag {
        GeneratedElementTag::Button => element
            .cursor(gpui::CursorStyle::PointingHand)
            .rounded(gpui::px(6.0))
            .px(gpui::px(10.0))
            .py(gpui::px(6.0)),
        GeneratedElementTag::Scroll => element,
        GeneratedElementTag::List => element.flex().flex_col().gap(gpui::px(4.0)),
        GeneratedElementTag::Item => element.p(gpui::px(4.0)),
        GeneratedElementTag::Span => element,
        _ => element,
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_input_primitive(
    style: StyleAttrs,
    value: String,
    placeholder: Option<String>,
    change: Option<String>,
    keydown: Option<String>,
    keyup: Option<String>,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{div, AppContext, ParentElement};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let input_id = format!(
        "gpui-elixir-input-{window_id}-{}",
        change.clone().unwrap_or_default()
    );
    let input = if let Some(input) = context.input_entities.get(&input_id).cloned() {
        context.cx.update_entity(&input, |input, _cx| {
            input.update_props(value.clone(), placeholder.clone(), change.clone());
        });
        input
    } else {
        let input = context.cx.new(|cx| {
            NativeTextInput::new(
                input_id.clone(),
                runtime.clone(),
                window_id,
                value.clone(),
                placeholder.clone(),
                change.clone(),
                cx,
            )
        });
        context
            .input_entities
            .insert(input_id.clone(), input.clone());
        input
    };

    let element = apply_generated_render_styles(div(), style).child(input);
    apply_input_events(element, value, change, keydown, keyup, runtime, window_id)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_container_primitive(
    tag: GeneratedElementTag,
    style: StyleAttrs,
    children: Vec<ElementNode>,
    click: Option<String>,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{div, InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let mut element = apply_generated_render_styles(div(), style);
    element = apply_container_semantics(element, tag);

    for child in children {
        element = element.child(child.render(context));
    }

    if tag == GeneratedElementTag::Scroll {
        let scroll_id = format!("gpui-elixir-scroll-{window_id}");
        let element = element.id(scroll_id).overflow_y_scroll();

        if let Some(event) = click {
            let runtime_for_click = runtime.clone();
            element
                .on_click(move |_event, _window, _cx| {
                    let _ = push_event(
                        &runtime_for_click,
                        NativeEvent::Click {
                            window_id,
                            event: event.clone(),
                        },
                    );
                })
                .into_any_element()
        } else {
            element.into_any_element()
        }
    } else {
        apply_click_event(element, click, runtime, window_id)
    }
}
