use std::sync::{Arc, Mutex};

use gpui_component::slider::{Slider, SliderEvent, SliderScale, SliderState, SliderValue};
use zed_gpui as gpui;

use crate::controlled::{ControlledBinding, SharedBinding};
use crate::host::ComponentHost;
use crate::host_contract::{
    ComponentEvent, ComponentEventEnvelope, ComponentValue, ComponentValueEvent,
};
use crate::SliderNode;
use gpui_core::Length;

pub type SharedEvent = Arc<Mutex<Option<String>>>;

include!("generated/slider.rs");

#[cfg(test)]
#[path = "slider_behavior_tests.rs"]
mod behavior_tests;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SliderConfig {
    pub min: f32,
    pub max: f32,
    pub step: f32,
    pub logarithmic: bool,
}
impl SliderConfig {
    pub fn accepts(self, value: f32) -> bool {
        self.min.is_finite()
            && self.max.is_finite()
            && self.step.is_finite()
            && value.is_finite()
            && self.min < self.max
            && self.step > 0.0
            && value >= self.min
            && value <= self.max
            && (!self.logarithmic || self.min > 0.0)
    }
}

pub struct ComponentSlider {
    pub state: gpui::Entity<SliderState>,
    pub binding: SharedBinding<f64>,
    pub release_event: SharedEvent,
    pub config: SliderConfig,
    pub subscription: gpui::Subscription,
}

pub fn config(node: &SliderNode) -> SliderConfig {
    SliderConfig {
        min: node.min as f32,
        max: node.max as f32,
        step: node.step as f32,
        logarithmic: node.scale.as_deref() == Some("logarithmic"),
    }
}
pub fn height(node: &SliderNode) -> f32 {
    match node.style.height {
        Some(Length::Pixels(value)) => value,
        _ if node.orientation.as_deref() == Some("vertical") => 120.0,
        _ => 24.0,
    }
}
pub fn number(value: SliderValue) -> f64 {
    match value {
        SliderValue::Single(value) => f64::from(value),
        SliderValue::Range(_, end) => f64::from(end),
    }
}

pub fn create<T: 'static>(
    node: &SliderNode,
    host: ComponentHost,
    window_id: u64,
    window: &gpui::Window,
    cx: &mut gpui::Context<T>,
) -> ComponentSlider {
    use gpui::AppContext;
    let config = config(node);
    let scale = if config.logarithmic {
        SliderScale::Logarithmic
    } else {
        SliderScale::Linear
    };
    let state = cx.new(|_| {
        SliderState::new()
            .min(config.min)
            .max(config.max)
            .step(config.step)
            .scale(scale)
            .default_value(node.value as f32)
    });
    let binding = Arc::new(Mutex::new(ControlledBinding::new(
        node.change.clone(),
        node.value,
    )));
    let release_event = Arc::new(Mutex::new(node.release.clone()));
    let event_binding = binding.clone();
    let event_release = release_event.clone();
    let subscription = cx.subscribe_in(&state, window, move |_, _, event: &SliderEvent, _, _| {
        handle_slider(&event_binding, &event_release, &host, window_id, event);
    });
    ComponentSlider {
        state,
        binding,
        release_event,
        config,
        subscription,
    }
}

pub fn render<T: 'static>(
    node: &SliderNode,
    slider: &mut ComponentSlider,
    window: &mut gpui::Window,
    cx: &mut gpui::Context<T>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement, Styled};
    let vertical = node.orientation.as_deref() == Some("vertical");
    if let Ok(mut release) = slider.release_event.lock() {
        *release = node.release.clone();
    }
    let apply = slider
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.value)
        })
        .unwrap_or(true);
    let current = number(slider.state.read(cx).value());
    if apply && (current - node.value).abs() > f64::from(f32::EPSILON) {
        slider.state.update(cx, |state, cx| {
            state.set_value(node.value as f32, window, cx)
        });
    }
    let mut element = Slider::new(&slider.state).disabled(node.disabled);
    element = if vertical {
        element.vertical()
    } else {
        element.horizontal()
    };
    if node.reverse {
        element = element.reverse();
    }
    gpui::div()
        .w_full()
        .h(gpui::px(height(node)))
        .child(crate::style::refine(element, node.style.clone()))
        .into_any_element()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn validates_ranges() {
        assert!(SliderConfig {
            min: 0.0,
            max: 10.0,
            step: 1.0,
            logarithmic: false
        }
        .accepts(4.0));
    }
}
