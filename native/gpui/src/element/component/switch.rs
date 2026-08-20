use crate::element::ElementRenderContext;
use crate::{gpui, SwitchComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
#[derive(Debug, PartialEq)]
struct SwitchAccessibility {
    label: String,
    toggled: gpui::Toggled,
}

#[cfg(feature = "components")]
fn switch_accessibility(label: String, checked: bool) -> SwitchAccessibility {
    SwitchAccessibility {
        label,
        toggled: if checked {
            gpui::Toggled::True
        } else {
            gpui::Toggled::False
        },
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        prelude::FluentBuilder, InteractiveElement, IntoElement, ParentElement, Role,
        StatefulInteractiveElement, Styled,
    };
    use gpui_component::{h_flex, spinner::Spinner, switch::Switch, Disableable, Sizable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let key_runtime = runtime.clone();
    let key_event = change_event.clone();
    let checked = node.checked;
    let unavailable = node.disabled || node.loading;
    let accessibility = switch_accessibility(node.label.clone(), checked);
    let switch_id = node.id.clone();
    let focus_handle = context
        .window
        .use_keyed_state(format!("{}-focus", node.id), context.cx, |_, cx| {
            cx.focus_handle()
        })
        .read(context.cx)
        .clone();
    let mut element = Switch::new(switch_id.clone())
        .checked(checked)
        .disabled(unavailable);
    element = element.label(node.label);
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };
    let element = apply_component_styles(element, node.style);
    let mut content = h_flex().items_center().gap_2().child(element);
    if node.loading {
        let spinner = match node.size.as_deref() {
            Some("xs") => Spinner::new().xsmall(),
            Some("lg") => Spinner::new().large(),
            _ => Spinner::new().small(),
        };
        content = content.child(spinner);
    }

    let mouse_runtime = runtime.clone();
    let mouse_event = change_event.clone();
    let mouse_focus = focus_handle.clone();

    gpui::div()
        .id(node.id)
        .debug_selector(|| switch_id)
        .role(Role::Switch)
        .aria_label(accessibility.label)
        .aria_toggled(accessibility.toggled)
        .track_focus(&focus_handle.tab_stop(!unavailable))
        .when(!unavailable, |element| {
            element.on_click(move |_event, window, cx| {
                mouse_focus.focus(window, cx);
                emit_change(&mouse_runtime, window_id, mouse_event.as_ref(), !checked);
            })
        })
        .on_key_down(move |event, _window, cx| {
            if unavailable || !matches!(event.keystroke.key.as_str(), "enter" | "space") {
                return;
            }
            emit_change(&key_runtime, window_id, key_event.as_ref(), !checked);
            cx.stop_propagation();
        })
        .child(content)
        .into_any_element()
}

#[cfg(feature = "components")]
fn emit_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&String>,
    value: bool,
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
            value: Some(EventValue::Boolean(value)),
        },
    );
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::{switch_accessibility, SwitchAccessibility};
    use crate::gpui;

    fn switch(checked: bool, disabled: bool, loading: bool) -> crate::ElementNode {
        crate::ElementNode::SwitchComponent(crate::SwitchComponentNode {
            style: crate::StyleAttrs::default(),
            id: "notifications".to_string(),
            checked,
            label: "Notifications".to_string(),
            size: None,
            disabled,
            loading,
            change: Some("notifications_changed".to_string()),
        })
    }

    #[gpui::test]
    fn rendered_switch_routes_pointer_and_keyboard_activation(cx: &mut gpui::TestAppContext) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            switch(false, false, false),
            gpui::size(gpui::px(240.0), gpui::px(80.0)),
        );

        harness.click_element("notifications");
        assert_change(harness.take_events(), true);

        harness.click_element("notifications");
        let _focus_activation = harness.take_events();
        harness.simulate_keystrokes("space");
        assert_change(harness.take_events(), true);
    }

    #[gpui::test]
    fn rendered_switch_blocks_disabled_and_loading_activation(cx: &mut gpui::TestAppContext) {
        for tree in [switch(false, true, false), switch(false, false, true)] {
            let mut harness = crate::test_harness::NativeTestHarness::new(
                cx,
                tree,
                gpui::size(gpui::px(240.0), gpui::px(80.0)),
            );

            harness.click_element("notifications");
            harness.simulate_keystrokes("space");
            assert!(harness.take_events().is_empty());
        }
    }

    fn assert_change(events: Vec<crate::NativeEvent>, expected: bool) {
        assert!(matches!(
            events.as_slice(),
            [crate::NativeEvent::Input {
                kind: crate::InputKind::Change,
                window_id: 7,
                event,
                value: Some(crate::EventValue::Boolean(value)),
            }] if event == "notifications_changed" && *value == expected
        ));
    }

    #[test]
    fn accessibility_tracks_label_and_controlled_state() {
        assert_eq!(
            switch_accessibility("Notifications".to_string(), true),
            SwitchAccessibility {
                label: "Notifications".to_string(),
                toggled: crate::gpui::Toggled::True,
            }
        );
        assert_eq!(
            switch_accessibility("Power".to_string(), false).label,
            "Power"
        );
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.label), Vec::new(), context)
}
