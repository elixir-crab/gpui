use crate::element::ElementRenderContext;
use crate::{gpui, SliderComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
#[derive(Debug, PartialEq)]
struct SliderAccessibility {
    label: String,
    orientation: gpui::Orientation,
}

#[cfg(feature = "components")]
fn slider_accessibility(label: String, vertical: bool) -> SliderAccessibility {
    SliderAccessibility {
        label,
        orientation: if vertical {
            gpui::Orientation::Vertical
        } else {
            gpui::Orientation::Horizontal
        },
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: SliderComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::component_registry::SharedEvent;
    use crate::element::controlled::{ControlledBinding, SharedBinding};
    use gpui::{
        AppContext, InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement,
        Styled,
    };
    use gpui_component::slider::{Slider, SliderEvent, SliderScale, SliderState};
    use gpui_components::slider::{ComponentSlider, SliderConfig};
    use std::sync::{Arc, Mutex};

    let vertical = node.orientation.as_deref() == Some("vertical");
    let accessibility = slider_accessibility(node.label.clone(), vertical);
    let accessibility_id = node.id.clone();
    let component_height = node
        .style
        .height
        .and_then(|height| match height {
            gpui::DefiniteLength::Absolute(gpui::AbsoluteLength::Pixels(height)) => {
                Some(f32::from(height))
            }
            _ => None,
        })
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
    component_style.height = Some(gpui::px(component_height).into());
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
                        (true, event_name, value, true)
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
                        (false, event_name, value, track_pending)
                    }
                };

                if let Some(event_name) = event_name {
                    let value = gpui_components::host_contract::ComponentValueEvent {
                        envelope: gpui_components::host_contract::ComponentEventEnvelope {
                            window_id,
                            event: event_name,
                        },
                        value: gpui_components::host_contract::ComponentValue::Number(value),
                    };
                    let event = if kind {
                        gpui_components::host_contract::ComponentEvent::Change(value)
                    } else {
                        gpui_components::host_contract::ComponentEvent::Release(value)
                    };
                    let result = runtime.component_host().emit(event);
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
                subscription,
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

    gpui::div()
        .id(format!("slider-accessibility-{accessibility_id}"))
        .role(gpui::Role::Group)
        .aria_label(accessibility.label)
        .aria_orientation(accessibility.orientation)
        .w_full()
        .h(gpui::px(component_height))
        .child(apply_component_styles(element, component_style))
        .into_any_element()
}

#[cfg(feature = "components")]
fn slider_number(value: gpui_component::slider::SliderValue) -> f64 {
    gpui_components::slider::number(value)
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::{slider_accessibility, SliderAccessibility};

    #[test]
    fn accessibility_tracks_label_and_orientation() {
        assert_eq!(
            slider_accessibility("Volume".to_string(), false),
            SliderAccessibility {
                label: "Volume".to_string(),
                orientation: crate::gpui::Orientation::Horizontal,
            }
        );
        assert_eq!(
            slider_accessibility("Zoom".to_string(), true),
            SliderAccessibility {
                label: "Zoom".to_string(),
                orientation: crate::gpui::Orientation::Vertical,
            }
        );
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
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
