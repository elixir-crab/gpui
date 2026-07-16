#[cfg(not(feature = "components"))]
use super::InputNode;
use super::{
    apply_generated_render_styles, ButtonComponentNode, CheckboxComponentNode,
    ElementRenderContext, InputComponentNode,
};
use crate::gpui;
#[cfg(feature = "components")]
use crate::gpui::Styled;
#[cfg(feature = "components")]
use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
};

#[cfg(feature = "components")]
struct ComponentInputBinding {
    change: Option<String>,
    confirmed_value: String,
    pending_values: VecDeque<String>,
}

#[cfg(feature = "components")]
pub(crate) struct ComponentInput {
    state: gpui::Entity<gpui_component::input::InputState>,
    binding: Arc<Mutex<ComponentInputBinding>>,
    placeholder: String,
    masked: bool,
    loading: bool,
    _subscription: gpui::Subscription,
}

#[cfg(feature = "components")]
impl ComponentInputBinding {
    fn reconcile_value(&mut self, value: &str) -> bool {
        if let Some(index) = self
            .pending_values
            .iter()
            .position(|pending| pending == value)
        {
            self.pending_values.drain(..=index);
            self.confirmed_value = value.to_string();
            return false;
        }

        if !self.pending_values.is_empty() && value == self.confirmed_value {
            return false;
        }

        self.pending_values.clear();
        self.confirmed_value = value.to_string();
        true
    }
}

#[cfg(feature = "components")]
pub(crate) fn render_button_component(
    node: ButtonComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, NativeEvent};
    use gpui::{IntoElement, ParentElement};
    use gpui_component::{
        button::{Button, ButtonVariants},
        Disableable, Selectable, Sizable,
    };

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let mut button = Button::new(node.id);

    button = match node.variant.as_deref() {
        Some("primary") => button.primary(),
        Some("secondary") => button.secondary(),
        Some("danger") => button.danger(),
        Some("warning") => button.warning(),
        Some("success") => button.success(),
        Some("info") => button.info(),
        Some("ghost") => button.ghost(),
        Some("link") => button.link(),
        Some("text") => button.text(),
        _ => button,
    };

    button = match node.size.as_deref() {
        Some("xs") => button.xsmall(),
        Some("sm") => button.small(),
        Some("lg") => button.large(),
        _ => button,
    };

    button = button
        .disabled(node.disabled)
        .selected(node.selected)
        .loading(node.loading);

    if node.outline {
        button = button.outline();
    }
    if node.compact {
        button = button.compact();
    }
    if let Some(label) = node.label {
        button = button.label(label);
    }
    for child in node.children {
        button = button.child(child.render(context));
    }
    if let Some(event) = node.click {
        button = button.on_click(move |_click, _window, _cx| {
            let _ = push_event(
                &runtime,
                NativeEvent::Click {
                    window_id,
                    event: event.clone(),
                },
            );
        });
    }

    apply_component_styles(button, node.style).into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_checkbox_component(
    node: CheckboxComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{IntoElement, ParentElement};
    use gpui_component::{checkbox::Checkbox, Disableable, Sizable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let mut checkbox = Checkbox::new(node.id)
        .checked(node.checked)
        .disabled(node.disabled);

    checkbox = match node.size.as_deref() {
        Some("xs") => checkbox.xsmall(),
        Some("sm") => checkbox.small(),
        Some("lg") => checkbox.large(),
        _ => checkbox,
    };

    if let Some(label) = node.label {
        checkbox = checkbox.label(label);
    }
    for child in node.children {
        checkbox = checkbox.child(child.render(context));
    }
    if let Some(event) = node.change {
        checkbox = checkbox.on_click(move |checked, _window, _cx| {
            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::Change,
                    window_id,
                    event: event.clone(),
                    value: Some(EventValue::Boolean(*checked)),
                },
            );
        });
    }

    apply_component_styles(checkbox, node.style).into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_input_component(
    _element_id: usize,
    node: InputComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{AppContext, IntoElement};
    use gpui_component::{
        input::{Input, InputEvent, InputState},
        Sizable,
    };

    context.active_component_input_ids.insert(node.id.clone());

    if !context.component_inputs.contains_key(&node.id) {
        let state = context.cx.new(|cx| {
            let mut state = InputState::new(context.window, cx)
                .default_value(node.value.clone())
                .placeholder(node.placeholder.clone().unwrap_or_default());
            if node.masked {
                state = state.masked(true);
            }
            state
        });
        let binding = Arc::new(Mutex::new(ComponentInputBinding {
            change: node.change.clone(),
            confirmed_value: node.value.clone(),
            pending_values: VecDeque::new(),
        }));
        let runtime = context.runtime.clone();
        let window_id = context.window_id;
        let event_binding = binding.clone();
        let subscription = context.cx.subscribe_in(
            &state,
            context.window,
            move |_root, state, event: &InputEvent, _window, cx| {
                if !matches!(event, InputEvent::Change) {
                    return;
                }

                let value = state.read(cx).value().to_string();
                let event = event_binding.lock().ok().and_then(|mut binding| {
                    binding.change.clone().inspect(|_event| {
                        binding.pending_values.push_back(value.clone());
                    })
                });

                if let Some(event) = event {
                    let result = push_event(
                        &runtime,
                        NativeEvent::Input {
                            kind: InputKind::Change,
                            window_id,
                            event,
                            value: Some(EventValue::String(value)),
                        },
                    );
                    if result.is_err() {
                        if let Ok(mut binding) = event_binding.lock() {
                            binding.pending_values.pop_back();
                        }
                    }
                }
            },
        );

        context.component_inputs.insert(
            node.id.clone(),
            ComponentInput {
                state,
                binding,
                placeholder: node.placeholder.clone().unwrap_or_default(),
                masked: node.masked,
                loading: false,
                _subscription: subscription,
            },
        );
    }

    let input = context
        .component_inputs
        .get_mut(&node.id)
        .expect("component input should exist");
    let apply_value = input
        .binding
        .lock()
        .map(|mut binding| {
            binding.change = node.change.clone();
            binding.reconcile_value(&node.value)
        })
        .unwrap_or(true);
    let current_value = input.state.read(context.cx).value();
    if apply_value && current_value.as_ref() != node.value {
        input.state.update(context.cx, |state, cx| {
            state.set_value(node.value.clone(), context.window, cx)
        });
    }

    let placeholder = node.placeholder.unwrap_or_default();
    if input.placeholder != placeholder {
        input.placeholder = placeholder.clone();
        input.state.update(context.cx, |state, cx| {
            state.set_placeholder(placeholder, context.window, cx)
        });
    }
    if input.masked != node.masked {
        input.masked = node.masked;
        input.state.update(context.cx, |state, cx| {
            state.set_masked(node.masked, context.window, cx)
        });
    }
    if input.loading != node.loading {
        input.loading = node.loading;
        input.state.update(context.cx, |state, cx| {
            state.set_loading(node.loading, context.window, cx)
        });
    }

    let mut element = Input::new(&input.state)
        .disabled(node.disabled)
        .cleanable(node.cleanable);
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };
    if node.masked {
        element = element.mask_toggle();
    }

    apply_component_styles(element, node.style).into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_input_component(
    element_id: usize,
    node: InputComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    super::render_input_primitive(
        element_id,
        InputNode {
            style: node.style,
            value: node.value,
            placeholder: node.placeholder,
            change: node.change,
            keydown: None,
            keyup: None,
        },
        context,
    )
}

#[cfg(feature = "components")]
fn apply_component_styles<T>(mut component: T, style: crate::StyleAttrs) -> T
where
    T: gpui::Styled,
{
    let mut styled = apply_generated_render_styles(gpui::div(), style);
    *component.style() = styled.style().clone();
    component
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_button_component(
    node: ButtonComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_checkbox_component(
    node: CheckboxComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(not(feature = "components"))]
fn render_component_fallback(
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
