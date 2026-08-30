use zed_gpui as gpui;

pub fn missing_resource_placeholder() -> gpui::AnyElement {
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

pub fn motion_easing(easing: &str, delta: f32) -> f32 {
    match easing {
        "ease_in" => delta * delta * delta,
        "ease_in_out" if delta < 0.5 => 4.0 * delta * delta * delta,
        "ease_in_out" => 1.0 - (-2.0 * delta + 2.0).powi(3) / 2.0,
        "ease_out" => 1.0 - (1.0 - delta).powi(3),
        _ => delta,
    }
}

pub fn lerp(from: f32, to: f32, delta: f32) -> f32 {
    from + (to - from) * delta
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn motion_helpers_reach_declared_endpoints() {
        for easing in ["linear", "ease_in", "ease_in_out", "ease_out"] {
            assert_eq!(motion_easing(easing, 0.0), 0.0);
            assert_eq!(motion_easing(easing, 1.0), 1.0);
        }
        assert_eq!(lerp(4.0, 8.0, 0.0), 4.0);
        assert_eq!(lerp(4.0, 8.0, 1.0), 8.0);
    }
}
