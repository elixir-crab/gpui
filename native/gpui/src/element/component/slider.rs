use crate::element::ElementRenderContext;
use crate::{gpui, SliderComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(super) fn render(
    node: SliderComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::component_registry::{ComponentSlider, SharedEvent, SliderConfig};
    use crate::element::controlled::{ControlledBinding, SharedBinding};
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{AppContext, IntoElement};
    use gpui_component::slider::{Slider, SliderEvent, SliderScale, SliderState};
    use std::sync::{Arc, Mutex};

    let vertical = node.orientation.as_deref() == Some("vertical");
    let component_height = node
        .style
        .height
        .unwrap_or(if vertical { 120.0 } else { 24.0 });
    let config = SliderConfig {
        min: node.min as f32,
        max: node.max as f32,
        step: node.step as f32,
        logarithmic: node.scale.as_deref() == Some("logarithmic"),
    };
    let native_value = node.value as f32;
    if !config.accepts(native_value) {
        return apply_component_styles(gpui::div(), node.style).into_any_element();
    }
    let mut component_style = node.style.clone();
    component_style.height = Some(component_height);
    component_style.flex_grow = Some(0.0);

    let rebuild = context
        .components
        .slider_mut(&node.id)
        .map(|slider| slider.config != config)
        .unwrap_or(true);

    if rebuild {
        let scale = if config.logarithmic {
            SliderScale::Logarithmic
        } else {
            SliderScale::Linear
        };
        let state = context.cx.new(|_cx| {
            SliderState::new()
                .min(config.min)
                .max(config.max)
                .step(config.step)
                .scale(scale)
                .default_value(native_value)
        });
        let binding: SharedBinding<f64> = Arc::new(Mutex::new(ControlledBinding::new(
            node.change.clone(),
            node.value,
        )));
        let release_event: SharedEvent = Arc::new(Mutex::new(node.release.clone()));
        let runtime = context.runtime.clone();
        let window_id = context.window_id;
        let event_binding = binding.clone();
        let event_release = release_event.clone();
        let subscription = context.cx.subscribe_in(
            &state,
            context.window,
            move |_root, _state, event: &SliderEvent, _window, _cx| {
                let (kind, event_name, value, track_pending) = match event {
                    SliderEvent::Change(value) => {
                        let value = slider_number(*value);
                        let event_name = event_binding.lock().ok().and_then(|mut binding| {
                            binding.event.clone().inspect(|_event| {
                                binding.push_pending(value);
                            })
                        });
                        (InputKind::Change, event_name, value, true)
                    }
                    SliderEvent::Release(value) => {
                        let value = slider_number(*value);
                        let event_name = event_release.lock().ok().and_then(|event| event.clone());
                        let track_pending = event_binding
                            .lock()
                            .map(|mut binding| {
                                if binding.event.is_none() && event_name.is_some() {
                                    binding.push_pending(value);
                                    true
                                } else {
                                    false
                                }
                            })
                            .unwrap_or(false);
                        (InputKind::Release, event_name, value, track_pending)
                    }
                };

                if let Some(event_name) = event_name {
                    let result = push_event(
                        &runtime,
                        NativeEvent::Input {
                            kind,
                            window_id,
                            event: event_name,
                            value: Some(EventValue::Number(value)),
                        },
                    );
                    if result.is_err() && track_pending {
                        if let Ok(mut binding) = event_binding.lock() {
                            binding.pop_pending();
                        }
                    }
                }
            },
        );

        context.components.insert_slider(
            &node.id,
            ComponentSlider {
                state,
                binding,
                release_event,
                config,
                _subscription: subscription,
            },
        );
    }

    let slider = context
        .components
        .slider_mut(&node.id)
        .expect("component slider should exist");
    if let Ok(mut release_event) = slider.release_event.lock() {
        *release_event = node.release.clone();
    }

    let apply_value = slider
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.value)
        })
        .unwrap_or(true);
    let current_value = slider_number(slider.state.read(context.cx).value());
    if apply_value && (current_value - node.value).abs() > f64::from(f32::EPSILON) {
        slider.state.update(context.cx, |state, cx| {
            state.set_value(native_value, context.window, cx)
        });
    }

    let mut element = Slider::new(&slider.state).disabled(node.disabled);
    if vertical {
        element = element.vertical();
    } else {
        element = element.horizontal();
    }
    if node.reverse {
        element = element.reverse();
    }

    apply_component_styles(element, component_style).into_any_element()
}

#[cfg(feature = "components")]
fn slider_number(value: gpui_component::slider::SliderValue) -> f64 {
    match value {
        gpui_component::slider::SliderValue::Single(value) => f64::from(value),
        gpui_component::slider::SliderValue::Range(_start, end) => f64::from(end),
    }
}

#[cfg(not(feature = "components"))]
pub(super) fn render(
    node: SliderComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(
        node.style,
        Some(node.value.to_string()),
        Vec::new(),
        context,
    )
}
