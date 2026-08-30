use crate::{Length, Style};
use zed_gpui as gpui;

fn length(value: Length) -> gpui::Length {
    match value {
        Length::Auto => gpui::Length::Auto,
        Length::Pixels(value) => gpui::px(value).into(),
        Length::Rems(value) => gpui::rems(value).into(),
        Length::Fraction(value) => gpui::relative(value).into(),
    }
}

fn definite_length(value: Length) -> Option<gpui::DefiniteLength> {
    match value {
        Length::Auto => None,
        Length::Pixels(value) => Some(gpui::px(value).into()),
        Length::Rems(value) => Some(gpui::rems(value).into()),
        Length::Fraction(value) => Some(gpui::relative(value)),
    }
}

pub fn apply_layout(mut element: gpui::Div, style: &Style) -> gpui::Div {
    use gpui::Styled;

    if let Some(width) = style.width.and_then(definite_length) {
        element = element.w(width);
    }
    if let Some(height) = style.height.and_then(definite_length) {
        element = element.h(height);
    }
    if let Some(value) = style.flex_grow {
        element = element.flex_grow(value);
    }
    if let Some(value) = style.flex_shrink {
        element = element.flex_shrink(value);
    }
    if let Some(value) = style.flex_basis {
        element = element.flex_basis(length(value));
    }
    if let Some(value) = style.opacity {
        element = element.opacity(value);
    }
    if let Some(value) = style.background {
        element = element.bg(gpui::rgba(value));
    }
    if let Some(value) = style.color {
        element = element.text_color(gpui::rgba(value));
    }
    if let Some(value) = style.gap {
        element = element.gap(gpui::px(value));
    }
    if let Some(value) = style.padding {
        element = element.p(gpui::px(value));
    }
    if let Some(value) = style.margin {
        element = element.m(gpui::px(value));
    }
    if let Some(value) = style.border_width {
        element = element.border(gpui::px(value));
    }
    if let Some(value) = style.border_color {
        element = element.border_color(gpui::rgba(value));
    }
    if let Some(value) = style.border_radius {
        element = element.rounded(gpui::px(value));
    }
    element
}
