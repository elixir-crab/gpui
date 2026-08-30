use zed_gpui as gpui;

pub fn input_height(size: Option<&str>, styled_height: Option<gpui::DefiniteLength>) -> f32 {
    let styled_height = styled_height.and_then(|height| match height {
        gpui::DefiniteLength::Absolute(gpui::AbsoluteLength::Pixels(height)) => {
            Some(f32::from(height))
        }
        _ => None,
    });

    styled_height.unwrap_or(match size {
        Some("xs") => 20.0,
        Some("sm") => 24.0,
        Some("lg") => 44.0,
        _ => 32.0,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn component_input_sizes_are_bounded() {
        assert_eq!(input_height(Some("xs"), None), 20.0);
        assert_eq!(input_height(Some("lg"), None), 44.0);
        assert_eq!(input_height(Some("unknown"), None), 32.0);
    }
}
