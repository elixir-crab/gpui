use gpui_core::Style;
use zed_gpui as gpui;

pub fn refine<T>(mut component: T, style: Style) -> T
where
    T: gpui::Styled,
{
    use gpui::{Refineable, Styled};

    let mut refinement = gpui_core::style::apply(gpui::div(), style);
    component.style().refine(refinement.style());
    component
}
