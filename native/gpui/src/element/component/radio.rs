use crate::element::ElementRenderContext;
use crate::{gpui, RadioGroupComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
#[derive(Debug, PartialEq)]
struct RadioGroupAccessibility {
    label: String,
    orientation: gpui::Orientation,
}

#[cfg(feature = "components")]
fn radio_group_accessibility(label: String, orientation: Option<&str>) -> RadioGroupAccessibility {
    RadioGroupAccessibility {
        label,
        orientation: if orientation == Some("horizontal") {
            gpui::Orientation::Horizontal
        } else {
            gpui::Orientation::Vertical
        },
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };
    use gpui_component::{h_flex, radio::Radio, v_flex, Sizable};

    let size = node.size.clone();
    let selected = node.value.clone();
    let accessibility = radio_group_accessibility(node.label.clone(), node.orientation.as_deref());
    let horizontal = accessibility.orientation == gpui::Orientation::Horizontal;
    let group_id = node.id.clone();
    let disabled = node.disabled;
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let key_options = node
        .options
        .iter()
        .map(|option| {
            (
                option.value.clone(),
                format!("{group_id}-{}", option.value),
                disabled || option.disabled,
            )
        })
        .collect::<Vec<_>>();
    let focus_handles = key_options
        .iter()
        .map(|(_value, id, _disabled)| {
            context
                .window
                .use_keyed_state(id.clone(), context.cx, |_, cx| cx.focus_handle())
                .read(context.cx)
                .clone()
        })
        .collect::<Vec<_>>();
    let selected_index = key_options
        .iter()
        .position(|(value, _id, _disabled)| Some(value) == selected.as_ref());
    let tab_index = selected_index
        .filter(|index| !key_options[*index].2)
        .or_else(|| {
            key_options
                .iter()
                .position(|(_value, _id, disabled)| !disabled)
        });

    let radios = node.options.into_iter().enumerate().map(|(index, option)| {
        let value = option.value;
        let checked = selected.as_ref() == Some(&value);
        let option_disabled = disabled || option.disabled;
        let event = change_event.clone();
        let event_runtime = runtime.clone();
        let mouse_focus = focus_handles[index].clone();
        let radio_id = format!("{group_id}-{value}");
        let selector = radio_id.clone();
        let mut radio = Radio::new(radio_id)
            .debug_selector(|| selector)
            .label(option.label)
            .checked(checked)
            .disabled(option_disabled)
            .tab_stop(false)
            .tab_index(-1)
            .on_click(move |new_checked, window, cx| {
                if *new_checked {
                    mouse_focus.focus(window, cx);
                    emit_change(&event_runtime, window_id, event.as_ref(), &value);
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
    .children(radios);
    let key_runtime = runtime.clone();
    let key_event = change_event.clone();
    let key_focus_handles = focus_handles.clone();
    let group_focus = context
        .window
        .use_keyed_state(format!("{group_id}-focus"), context.cx, |_, cx| {
            cx.focus_handle()
        })
        .read(context.cx)
        .clone();
    let element = crate::apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .debug_selector(|| group_id)
        .track_focus(&group_focus.tab_stop(!disabled && !key_options.is_empty()))
        .role(Role::RadioGroup)
        .aria_label(accessibility.label)
        .aria_orientation(accessibility.orientation)
        .on_key_down(move |event, window, cx| {
            let focused_index = key_focus_handles
                .iter()
                .position(|handle| handle.is_focused(window));
            let current = focused_index.or(selected_index).or(tab_index);
            let target = match event.keystroke.key.as_str() {
                "left" | "up" => previous_enabled(&key_options, current),
                "right" | "down" => next_enabled(&key_options, current),
                "enter" | "space" => current.filter(|index| !key_options[*index].2),
                _other => None,
            };
            let Some(target) = target else {
                return;
            };
            let (value, _id, _disabled) = &key_options[target];
            key_focus_handles[target].focus(window, cx);
            emit_change(&key_runtime, window_id, key_event.as_ref(), value);
            cx.stop_propagation();
        })
        .child(group);

    element.into_any_element()
}

#[cfg(feature = "components")]
fn next_enabled(options: &[(String, String, bool)], current: Option<usize>) -> Option<usize> {
    enabled_from(
        options,
        current.unwrap_or(options.len().saturating_sub(1)),
        1,
    )
}

#[cfg(feature = "components")]
fn previous_enabled(options: &[(String, String, bool)], current: Option<usize>) -> Option<usize> {
    enabled_from(
        options,
        current.unwrap_or(0),
        options.len().saturating_sub(1),
    )
}

#[cfg(feature = "components")]
fn enabled_from(
    options: &[(String, String, bool)],
    current: usize,
    increment: usize,
) -> Option<usize> {
    if options.is_empty() {
        return None;
    }

    (1..=options.len())
        .map(|offset| (current + offset * increment) % options.len())
        .find(|index| !options[*index].2)
}

#[cfg(feature = "components")]
fn emit_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&String>,
    value: &str,
) {
    use crate::{push_event, EventValue, InputKind, NativeEvent};

    let Some(event) = event else {
        return;
    };
    let _ = push_event(
        runtime,
        NativeEvent::Input {
            kind: InputKind::Change,
            window_id,
            event: event.clone(),
            value: Some(EventValue::String(value.to_string())),
        },
    );
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::{radio_group_accessibility, RadioGroupAccessibility};
    use crate::gpui;

    fn radio_group(disabled: bool) -> crate::ElementNode {
        crate::ElementNode::RadioGroupComponent(crate::RadioGroupComponentNode {
            style: crate::StyleAttrs::default(),
            id: "plan".to_string(),
            label: "Plan".to_string(),
            value: Some("free".to_string()),
            options: vec![
                option("Free", "free", false),
                option("Pro", "pro", true),
                option("Team", "team", false),
            ],
            orientation: Some("horizontal".to_string()),
            size: None,
            disabled,
            change: Some("plan_changed".to_string()),
        })
    }

    fn option(label: &str, value: &str, disabled: bool) -> crate::RadioOptionNode {
        crate::RadioOptionNode {
            label: label.to_string(),
            value: value.to_string(),
            disabled,
        }
    }

    #[gpui::test]
    fn rendered_radio_group_routes_pointer_selection_and_blocks_disabled_options(
        cx: &mut gpui::TestAppContext,
    ) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            radio_group(false),
            gpui::size(gpui::px(320.0), gpui::px(100.0)),
        );

        harness.click_element("plan-team");
        assert_selection(harness.take_events(), "team");

        harness.click_element("plan-pro");
        assert!(harness.take_events().is_empty());
    }

    #[gpui::test]
    fn rendered_radio_group_keyboard_navigation_skips_disabled_options(
        cx: &mut gpui::TestAppContext,
    ) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            radio_group(false),
            gpui::size(gpui::px(320.0), gpui::px(100.0)),
        );

        harness.click_element("plan");
        let _pointer_events = harness.take_events();
        harness.simulate_keystrokes("right");
        assert_selection(harness.take_events(), "team");
    }

    #[gpui::test]
    fn disabled_radio_group_blocks_pointer_and_keyboard_selection(cx: &mut gpui::TestAppContext) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            radio_group(true),
            gpui::size(gpui::px(320.0), gpui::px(100.0)),
        );

        harness.click_element("plan-team");
        harness.simulate_keystrokes("right space");
        assert!(harness.take_events().is_empty());
    }

    fn assert_selection(events: Vec<crate::NativeEvent>, expected: &str) {
        assert!(matches!(
            events.as_slice(),
            [crate::NativeEvent::Input {
                kind: crate::InputKind::Change,
                window_id: 7,
                event,
                value: Some(crate::EventValue::String(value)),
            }] if event == "plan_changed" && value == expected
        ));
    }

    #[test]
    fn accessibility_tracks_label_and_orientation() {
        assert_eq!(
            radio_group_accessibility("Plan".to_string(), Some("horizontal")),
            RadioGroupAccessibility {
                label: "Plan".to_string(),
                orientation: crate::gpui::Orientation::Horizontal,
            }
        );
        assert_eq!(
            radio_group_accessibility("Priority".to_string(), None),
            RadioGroupAccessibility {
                label: "Priority".to_string(),
                orientation: crate::gpui::Orientation::Vertical,
            }
        );
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: RadioGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let label = node
        .value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone());

    render_component_fallback(node.style, label, Vec::new(), context)
}
