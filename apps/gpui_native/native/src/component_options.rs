use crate::{RadioOptionNode, SelectOptionNode};

#[cfg(feature = "components")]
pub(crate) fn radio_options_to_owner(
    options: Vec<RadioOptionNode>,
) -> Vec<gpui_components::OptionNode> {
    options
        .into_iter()
        .map(|option| gpui_components::OptionNode {
            label: option.label,
            value: option.value,
            disabled: option.disabled,
        })
        .collect()
}

#[cfg(feature = "components")]
pub(crate) fn select_options_to_owner(
    options: Vec<SelectOptionNode>,
) -> Vec<gpui_components::OptionNode> {
    options
        .into_iter()
        .map(|option| gpui_components::OptionNode {
            label: option.label,
            value: option.value,
            disabled: false,
        })
        .collect()
}
