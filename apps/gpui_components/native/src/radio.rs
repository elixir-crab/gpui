use crate::controls::emit_string_change;
use crate::host::ComponentHost;
use crate::rendered_control::{Accessibility, RenderedControl};
use crate::RadioGroupNode;
use zed_gpui as gpui;

pub struct RadioContext<'a> {
    pub window_id: u64,
    pub host: ComponentHost,
    pub window: &'a mut gpui::Window,
    pub cx: &'a mut gpui::App,
}

pub fn render(node: RadioGroupNode, context: &mut RadioContext<'_>) -> RenderedControl {
    use gpui::{IntoElement, ParentElement, Styled};
    use gpui_component::{h_flex, radio::Radio, v_flex, Sizable};
    let horizontal = node.orientation.as_deref() == Some("horizontal");
    let selected = node.value.clone();
    let focus_handles = node
        .options
        .iter()
        .map(|option| {
            context
                .window
                .use_keyed_state(
                    format!("{}-{}", node.id, option.value),
                    context.cx,
                    |_, cx| cx.focus_handle(),
                )
                .read(context.cx)
                .clone()
        })
        .collect::<Vec<_>>();
    let tab_index = node
        .options
        .iter()
        .position(|option| {
            selected.as_ref() == Some(&option.value) && !node.disabled && !option.disabled
        })
        .or_else(|| {
            node.options
                .iter()
                .position(|option| !node.disabled && !option.disabled)
        });
    let host = context.host.clone();
    let event = node.change.clone();
    let window_id = context.window_id;
    let size = node.size.clone();
    let radios = node.options.into_iter().enumerate().map(|(index, option)| {
        let value = option.value;
        let host = host.clone();
        let event = event.clone();
        let mut radio = Radio::new(format!("{}-{value}", node.id))
            .label(option.label)
            .checked(selected.as_ref() == Some(&value))
            .disabled(node.disabled || option.disabled)
            .tab_stop(tab_index == Some(index))
            .tab_index(if tab_index == Some(index) { 0 } else { -1 })
            .on_click(move |checked, _, _| {
                if *checked {
                    emit_string_change(&host, window_id, event.as_ref(), &value);
                }
            });
        radio = match size.as_deref() {
            Some("xs") => radio.xsmall(),
            Some("sm") => radio.small(),
            Some("lg") => radio.large(),
            _ => radio,
        };
        radio
    });
    let group = if horizontal {
        h_flex().w_full().flex_wrap()
    } else {
        v_flex()
    }
    .gap_3()
    .children(radios)
    .into_any_element();
    RenderedControl {
        element: group,
        test_id: node.id,
        primary_focus: tab_index.and_then(|index| focus_handles.get(index).cloned()),
        accessibility: Accessibility::group(
            node.label,
            if horizontal {
                gpui::Orientation::Horizontal
            } else {
                gpui::Orientation::Vertical
            },
            node.disabled,
        ),
    }
}
