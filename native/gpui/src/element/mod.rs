use crate::*;

pub(crate) mod component;
#[cfg(feature = "components")]
pub(crate) mod component_registry;
pub(crate) mod controlled;
pub(crate) mod event;

use component::{
    render_accordion_component, render_accordion_item_component, render_button_component,
    render_checkbox_component, render_combobox_component, render_input_component,
    render_popover_component, render_popover_content_component, render_popover_trigger_component,
    render_radio_group_component, render_select_component, render_slider_component,
    render_switch_component, render_tabs_component,
};
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
    Input(InputNode),
    ButtonComponent(ButtonComponentNode),
    PopoverComponent(PopoverComponentNode),
    PopoverTriggerComponent(PopoverTriggerComponentNode),
    PopoverContentComponent(PopoverContentComponentNode),
    CheckboxComponent(CheckboxComponentNode),
    InputComponent(InputComponentNode),
    SelectComponent(SelectComponentNode),
    ComboboxComponent(ComboboxComponentNode),
    SwitchComponent(SwitchComponentNode),
    RadioGroupComponent(RadioGroupComponentNode),
    SliderComponent(SliderComponentNode),
    TabsComponent(TabsComponentNode),
    AccordionComponent(AccordionComponentNode),
    AccordionItemComponent(AccordionItemComponentNode),
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
#[derive(Clone, Debug)]
pub(crate) struct InputNode {
    pub(crate) style: StyleAttrs,
    pub(crate) value: String,
    pub(crate) placeholder: Option<String>,
    pub(crate) change: Option<String>,
    pub(crate) keydown: Option<String>,
    pub(crate) keyup: Option<String>,
}

#[cfg(feature = "real-gpui")]
pub(crate) struct ElementRenderContext<'a, 'cx> {
    pub(crate) runtime: SharedRuntime,
    pub(crate) window_id: u64,
    pub(crate) next_element_id: usize,
    pub(crate) active_input_ids: &'a mut HashSet<String>,
    pub(crate) input_entities: &'a mut HashMap<String, gpui::Entity<NativeTextInput>>,
    #[cfg(feature = "components")]
    pub(crate) components: &'a mut component_registry::ComponentRegistry,
    #[cfg(feature = "components")]
    pub(crate) window: &'a mut gpui::Window,
    pub(crate) cx: &'a mut gpui::Context<'cx, ElixirRoot>,
}

#[cfg(feature = "real-gpui")]
impl ElementRenderContext<'_, '_> {
    fn allocate_element_id(&mut self) -> usize {
        let element_id = self.next_element_id;
        self.next_element_id += 1;
        element_id
    }
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
        let element_id = context.allocate_element_id();

        match self {
            Self::Text { text, style } => render_text_primitive(text, style),
            Self::Image { image, style } => {
                render_image_primitive(image, style, context.runtime.clone(), context.window_id)
            }
            Self::Input(input) => render_input_primitive(element_id, input, context),
            Self::ButtonComponent(button) => render_button_component(button, context),
            Self::PopoverComponent(popover) => render_popover_component(popover, context),
            Self::PopoverTriggerComponent(trigger) => {
                render_popover_trigger_component(trigger, context)
            }
            Self::PopoverContentComponent(content) => {
                render_popover_content_component(content, context)
            }
            Self::CheckboxComponent(checkbox) => render_checkbox_component(checkbox, context),
            Self::InputComponent(input) => render_input_component(element_id, input, context),
            Self::SelectComponent(select) => render_select_component(select, context),
            Self::ComboboxComponent(combobox) => render_combobox_component(combobox, context),
            Self::SwitchComponent(switch) => render_switch_component(switch, context),
            Self::RadioGroupComponent(radio) => render_radio_group_component(radio, context),
            Self::SliderComponent(slider) => render_slider_component(slider, context),
            Self::TabsComponent(tabs) => render_tabs_component(tabs, context),
            Self::AccordionComponent(accordion) => render_accordion_component(accordion, context),
            Self::AccordionItemComponent(item) => render_accordion_item_component(item, context),
            Self::Div {
                tag,
                style,
                children,
                click,
            } => render_container_primitive(element_id, tag, style, children, click, context),
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
    element_id: usize,
    input_node: InputNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{div, AppContext, ParentElement};

    let InputNode {
        style,
        value,
        placeholder,
        change,
        keydown,
        keyup,
    } = input_node;
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let input_id = format!("gpui-elixir-input-{window_id}-{element_id}");
    context.active_input_ids.insert(input_id.clone());
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
    apply_input_events(element, input_id, keydown, keyup, runtime, window_id)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_container_primitive(
    element_id: usize,
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
        let scroll_id = format!("gpui-elixir-scroll-{window_id}-{element_id}");
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
        apply_click_event(element, element_id, click, runtime, window_id)
    }
}
