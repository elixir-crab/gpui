use zed_gpui as gpui;

pub struct RenderedControl {
    pub element: gpui::AnyElement,
    pub test_id: String,
    pub primary_focus: Option<gpui::FocusHandle>,
    pub accessibility: Accessibility,
}

#[derive(Clone, Debug)]
pub struct Accessibility {
    pub role: gpui::Role,
    pub label: Option<String>,
    pub orientation: Option<gpui::Orientation>,
    pub toggled: Option<gpui::Toggled>,
    pub disabled: bool,
}

impl Accessibility {
    pub fn group(label: String, orientation: gpui::Orientation, disabled: bool) -> Self {
        Self {
            role: gpui::Role::Group,
            label: Some(label),
            orientation: Some(orientation),
            toggled: None,
            disabled,
        }
    }
}
