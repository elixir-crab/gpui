#[cfg(not(feature = "components"))]
use super::render_component_fallback;
#[cfg(feature = "components")]
use super::{apply_component_styles, component_input_height, constrain_full_size_component};
#[cfg(feature = "components")]
use crate::element::component_registry::{
    filter_options, ComponentCombobox, ComponentInput, ComponentSelect, NativeComboboxDelegate,
    NativeSelectOption, SharedEvent, SharedQuery,
};
#[cfg(feature = "components")]
use crate::element::controlled::{ControlledBinding, SharedBinding};
#[cfg(not(feature = "components"))]
use crate::InputNode;
#[cfg(feature = "components")]
use crate::SelectOptionNode;
use crate::{
    gpui, ComboboxComponentNode, ElementRenderContext, InputComponentNode, SelectComponentNode,
};
#[cfg(feature = "components")]
use std::sync::{Arc, Mutex};

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

    if context.components.input_mut(&node.id).is_none() {
        let state = context.cx.new(|cx| {
            let mut state = InputState::new(context.window, cx)
                .default_value(node.value.clone())
                .placeholder(node.placeholder.clone().unwrap_or_default());
            if node.masked {
                state = state.masked(true);
            }
            state
        });
        let binding: SharedBinding<String> = Arc::new(Mutex::new(ControlledBinding::new(
            node.change.clone(),
            node.value.clone(),
        )));
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
                    binding.event.clone().inspect(|_event| {
                        binding.push_pending(value.clone());
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
                            binding.pop_pending();
                        }
                    }
                }
            },
        );

        context.components.insert_input(
            &node.id,
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
        .components
        .input_mut(&node.id)
        .expect("component input should exist");
    let apply_value = input
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.value)
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

#[cfg(feature = "components")]
pub(crate) fn render_select_component(
    node: SelectComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::AppContext;

    let component_height = component_input_height(node.size.as_deref(), node.style.height);
    use gpui_component::{
        select::{Select, SelectEvent, SelectState},
        IndexPath, Sizable,
    };

    let options = native_select_options(&node.options);

    if context.components.select_mut(&node.id).is_none() {
        let selected_index = node.value.as_ref().and_then(|value| {
            options
                .iter()
                .position(|option| option.value.as_ref() == value)
                .map(IndexPath::new)
        });
        let state = context
            .cx
            .new(|cx| SelectState::new(options.clone(), selected_index, context.window, cx));
        let binding: SharedBinding<Option<String>> = Arc::new(Mutex::new(ControlledBinding::new(
            node.change.clone(),
            node.value.clone(),
        )));
        let runtime = context.runtime.clone();
        let window_id = context.window_id;
        let event_binding = binding.clone();
        let subscription = context.cx.subscribe_in(
            &state,
            context.window,
            move |_root, _state, event: &SelectEvent<Vec<NativeSelectOption>>, _window, _cx| {
                let SelectEvent::Confirm(value) = event;
                let value = value.as_ref().map(ToString::to_string);
                let event = event_binding.lock().ok().and_then(|mut binding| {
                    binding.event.clone().inspect(|_event| {
                        binding.push_pending(value.clone());
                    })
                });

                if let Some(event) = event {
                    let event_value = value
                        .clone()
                        .map(EventValue::String)
                        .unwrap_or(EventValue::Nil);
                    let result = push_event(
                        &runtime,
                        NativeEvent::Input {
                            kind: InputKind::Change,
                            window_id,
                            event,
                            value: Some(event_value),
                        },
                    );
                    if result.is_err() {
                        if let Ok(mut binding) = event_binding.lock() {
                            binding.pop_pending();
                        }
                    }
                }
            },
        );

        context.components.insert_select(
            &node.id,
            ComponentSelect {
                state,
                binding,
                options: options.clone(),
                _subscription: subscription,
            },
        );
    }

    let select = context
        .components
        .select_mut(&node.id)
        .expect("component select should exist");
    let options_changed = select.options != options;
    if options_changed {
        select.options = options.clone();
        select.state.update(context.cx, |state, cx| {
            state.set_items(options, context.window, cx)
        });
    }

    let apply_value = select
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.value)
        })
        .unwrap_or(true)
        || options_changed;
    let current_value = select
        .state
        .read(context.cx)
        .selected_value()
        .map(ToString::to_string);
    if apply_value && current_value != node.value {
        let value = node.value.clone();
        select.state.update(context.cx, |state, cx| match value {
            Some(value) => state.set_selected_value(&value.into(), context.window, cx),
            None => state.set_selected_index(None, context.window, cx),
        });
    }

    let mut element = Select::new(&select.state)
        .disabled(node.disabled)
        .cleanable(node.cleanable);
    if let Some(placeholder) = node.placeholder {
        element = element.placeholder(placeholder);
    }
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };

    constrain_full_size_component(
        apply_component_styles(element, node.style),
        component_height,
    )
}

#[cfg(feature = "components")]
pub(crate) fn render_combobox_component(
    node: ComboboxComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::AppContext;

    let component_height = component_input_height(node.size.as_deref(), node.style.height);
    use gpui_component::{
        combobox::{Combobox, ComboboxEvent, ComboboxState},
        IndexPath, Sizable,
    };

    let options = native_select_options(&node.options);

    if context.components.combobox_mut(&node.id).is_none() {
        let selected_indices = node
            .value
            .as_ref()
            .and_then(|value| {
                options
                    .iter()
                    .position(|option| option.value.as_ref() == value)
            })
            .map(IndexPath::new)
            .into_iter()
            .collect::<Vec<_>>();
        let search_event: SharedEvent = Arc::new(Mutex::new(node.search.clone()));
        let query: SharedQuery = Arc::new(Mutex::new(String::new()));
        let delegate = NativeComboboxDelegate::new(
            options.clone(),
            context.runtime.clone(),
            context.window_id,
            search_event.clone(),
            query.clone(),
        );
        let state = context.cx.new(|cx| {
            ComboboxState::new(delegate, selected_indices, context.window, cx).searchable(true)
        });
        let binding: SharedBinding<Option<String>> = Arc::new(Mutex::new(ControlledBinding::new(
            node.change.clone(),
            node.value.clone(),
        )));
        let runtime = context.runtime.clone();
        let window_id = context.window_id;
        let event_binding = binding.clone();
        let subscription = context.cx.subscribe_in(
            &state,
            context.window,
            move |_root, _state, event: &ComboboxEvent<NativeComboboxDelegate>, _window, _cx| {
                let ComboboxEvent::Change(values) = event else {
                    return;
                };
                let value = values.first().map(ToString::to_string);
                let event = event_binding.lock().ok().and_then(|mut binding| {
                    binding.event.clone().inspect(|_event| {
                        binding.push_pending(value.clone());
                    })
                });

                if let Some(event) = event {
                    let event_value = value
                        .clone()
                        .map(EventValue::String)
                        .unwrap_or(EventValue::Nil);
                    let result = push_event(
                        &runtime,
                        NativeEvent::Input {
                            kind: InputKind::Change,
                            window_id,
                            event,
                            value: Some(event_value),
                        },
                    );
                    if result.is_err() {
                        if let Ok(mut binding) = event_binding.lock() {
                            binding.pop_pending();
                        }
                    }
                }
            },
        );

        context.components.insert_combobox(
            &node.id,
            ComponentCombobox {
                state,
                binding,
                search_event,
                query,
                options: options.clone(),
                _subscription: subscription,
            },
        );
    }

    let combobox = context
        .components
        .combobox_mut(&node.id)
        .expect("component combobox should exist");
    if let Ok(mut search_event) = combobox.search_event.lock() {
        *search_event = node.search.clone();
    }

    let options_changed = combobox.options != options;
    if options_changed {
        combobox.options = options.clone();
        let delegate = NativeComboboxDelegate::new(
            options.clone(),
            context.runtime.clone(),
            context.window_id,
            combobox.search_event.clone(),
            combobox.query.clone(),
        );
        combobox.state.update(context.cx, |state, cx| {
            state.set_items(delegate, context.window, cx)
        });
    }

    let apply_value = combobox
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.value)
        })
        .unwrap_or(true)
        || options_changed;
    let current_value = combobox
        .state
        .read(context.cx)
        .selected_value()
        .map(|value| value.to_string());
    if apply_value && current_value != node.value {
        let query = combobox
            .query
            .lock()
            .map(|query| query.clone())
            .unwrap_or_default();
        let filtered = filter_options(&options, &query);
        let selected_indices = node
            .value
            .as_ref()
            .and_then(|value| {
                filtered
                    .iter()
                    .position(|option| option.value.as_ref() == value)
            })
            .map(IndexPath::new)
            .into_iter()
            .collect::<Vec<_>>();
        combobox.state.update(context.cx, |state, cx| {
            state.set_selected_indices(selected_indices, context.window, cx)
        });
    }

    let mut element = Combobox::new(&combobox.state)
        .disabled(node.disabled || node.loading)
        .cleanable(node.cleanable);
    if let Some(placeholder) = node.placeholder {
        element = element.placeholder(placeholder);
    }
    if let Some(search_placeholder) = node.search_placeholder {
        element = element.search_placeholder(search_placeholder);
    }
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };

    constrain_full_size_component(
        apply_component_styles(element, node.style),
        component_height,
    )
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_combobox_component(
    node: ComboboxComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let label = node
        .value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone())
        .or(node.placeholder);

    render_component_fallback(node.style, label, Vec::new(), context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_select_component(
    node: SelectComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let label = node
        .value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone())
        .or(node.placeholder);

    render_component_fallback(node.style, label, Vec::new(), context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_input_component(
    element_id: usize,
    node: InputComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    super::super::render_input_primitive(
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
fn native_select_options(options: &[SelectOptionNode]) -> Vec<NativeSelectOption> {
    options
        .iter()
        .map(|option| NativeSelectOption {
            label: option.label.clone().into(),
            value: option.value.clone().into(),
        })
        .collect()
}
