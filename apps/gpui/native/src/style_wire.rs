use crate::{Length, Style};
use zed_gpui as gpui;

pub fn length(value: gpui::Length) -> Length {
    match value {
        gpui::Length::Auto => Length::Auto,
        gpui::Length::Definite(value) => definite_length(value),
    }
}

pub fn definite_length(value: gpui::DefiniteLength) -> Length {
    match value {
        gpui::DefiniteLength::Fraction(value) => Length::Fraction(value),
        gpui::DefiniteLength::Absolute(gpui::AbsoluteLength::Pixels(value)) => {
            Length::Pixels(f32::from(value))
        }
        gpui::DefiniteLength::Absolute(gpui::AbsoluteLength::Rems(value)) => Length::Rems(value.0),
    }
}

pub struct StyleBuilder {
    style: Style,
}

impl StyleBuilder {
    pub fn new() -> Self {
        Self {
            style: Style::default(),
        }
    }
    pub fn finish(self) -> Style {
        self.style
    }
    pub fn style_mut(&mut self) -> &mut Style {
        &mut self.style
    }
}

impl Default for StyleBuilder {
    fn default() -> Self {
        Self::new()
    }
}
