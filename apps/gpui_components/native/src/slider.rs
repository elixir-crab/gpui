use std::sync::{Arc, Mutex};

use gpui_component::slider::{SliderState, SliderValue};
use zed_gpui as gpui;

use crate::controlled::SharedBinding;

pub type SharedEvent = Arc<Mutex<Option<String>>>;

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

pub fn number(value: SliderValue) -> f64 {
    match value {
        SliderValue::Single(value) => f64::from(value),
        SliderValue::Range(_start, end) => f64::from(end),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_linear_and_logarithmic_ranges() {
        assert!(SliderConfig {
            min: 0.0,
            max: 10.0,
            step: 1.0,
            logarithmic: false
        }
        .accepts(4.0));
        assert!(!SliderConfig {
            min: 0.0,
            max: 10.0,
            step: 1.0,
            logarithmic: true
        }
        .accepts(4.0));
    }
}
