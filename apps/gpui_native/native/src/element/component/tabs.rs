use crate::element::ElementRenderContext;
use crate::{gpui, TabsComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: TabsComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        AccessibleAction, InteractiveElement, IntoElement, MouseButton, ParentElement,
        StatefulInteractiveElement, Styled,
    };
    use gpui_component::{
        tab::{Tab, TabBar},
        Sizable,
    };

    let selected_index = node.value.as_ref().and_then(|value| {
        node.options
            .iter()
            .position(|option| &option.value == value)
    });
    let values = node
        .options
        .iter()
        .map(|option| option.value.clone())
        .collect::<Vec<_>>();
    let focus_handles = values
        .iter()
        .map(|value| {
            context
                .window
                .use_keyed_state(
                    format!("{}-tab-focus-{value}", node.id),
                    context.cx,
                    |_, cx| cx.focus_handle(),
                )
                .read(context.cx)
                .clone()
        })
        .collect::<Vec<_>>();
    let tab_stop_index = selected_index.or_else(|| (!node.options.is_empty()).then_some(0));
    let group_focus = context
        .window
        .use_keyed_state(
            format!("{}-tab-group-focus", node.id),
            context.cx,
            |_, cx| cx.focus_handle(),
        )
        .read(context.cx)
        .clone();
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let disabled = node.disabled;
    let tabs = node
        .options
        .iter()
        .enumerate()
        .map(|(index, option)| {
            let focus = focus_handles[index].clone();
            let mouse_focus = focus.clone();
            let key_focus_handles = focus_handles.clone();
            let key_values = values.clone();
            let key_runtime = runtime.clone();
            let key_event = change_event.clone();
            let action_runtime = runtime.clone();
            let action_event = change_event.clone();
            let action_value = option.value.clone();
            let mut tab = Tab::new()
                .label(option.label.clone())
                .disabled(disabled)
                .track_focus(&focus)
                .tab_index(-1);
            if disabled {
                tab = tab.a11y_synthetic_children(|builder| {
                    builder.parent_node().set_disabled();
                });
            } else {
                tab = tab
                    .focus_visible(|style| style.border_2().border_color(gpui::rgb(0x60a5fa)))
                    .on_mouse_down(MouseButton::Left, move |_event, window, cx| {
                        mouse_focus.focus(window, cx);
                    })
                    .on_key_down(move |event, window, cx| {
                        let Some(target) = gpui_components::controls::tab_key_target(
                            event.keystroke.key.as_str(),
                            index,
                            key_focus_handles.len(),
                        ) else {
                            return;
                        };
                        key_focus_handles[target].focus(window, cx);
                        emit_change(
                            &key_runtime,
                            window_id,
                            key_event.as_ref(),
                            &key_values[target],
                        );
                        cx.stop_propagation();
                    })
                    .on_a11y_action(AccessibleAction::Click, move |_data, _window, _cx| {
                        emit_change(
                            &action_runtime,
                            window_id,
                            action_event.as_ref(),
                            &action_value,
                        );
                    });
            }
            tab
        })
        .collect::<Vec<_>>();
    let group_key_focus_handles = focus_handles.clone();
    let group_key_values = values.clone();
    let group_key_runtime = runtime.clone();
    let group_key_event = change_event.clone();
    let group_focus_for_tabs = group_focus.clone();
    let tabs_id = node.id.clone();
    let mut element = TabBar::new(node.id.clone())
        .children(tabs)
        .menu(node.menu)
        .on_click(move |index, window, cx| {
            group_focus_for_tabs.focus(window, cx);
            let Some(event) = change_event.as_ref() else {
                return;
            };
            let Some(value) = values.get(*index) else {
                return;
            };
            emit_change(&runtime, window_id, Some(event), value);
        });
    if let Some(selected_index) = selected_index {
        element = element.selected_index(selected_index);
    }
    element = match node.variant.as_deref() {
        Some("outline") => element.outline(),
        Some("pill") => element.pill(),
        Some("segmented") => element.segmented(),
        Some("underline") => element.underline(),
        _ => element,
    };
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };

    let element = gpui::div()
        .id(format!("{}-keyboard", node.id))
        .track_focus(&group_focus.clone().tab_stop(!disabled))
        .on_key_down(move |event, window, cx| {
            if disabled {
                return;
            }
            let current = group_key_focus_handles
                .iter()
                .position(|handle| handle.is_focused(window))
                .or(selected_index)
                .or(tab_stop_index);
            let Some(current) = current else {
                return;
            };
            let Some(target) = gpui_components::controls::tab_key_target(
                event.keystroke.key.as_str(),
                current,
                group_key_values.len(),
            ) else {
                return;
            };
            group_key_focus_handles[target].focus(window, cx);
            emit_change(
                &group_key_runtime,
                window_id,
                group_key_event.as_ref(),
                &group_key_values[target],
            );
            cx.stop_propagation();
        })
        .child(apply_component_styles(element, node.style));
    crate::element::register_test_target(element, tabs_id, Some(group_focus), context)
        .into_any_element()
}

#[cfg(feature = "components")]
fn emit_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&String>,
    value: &str,
) {
    gpui_components::controls::emit_string_change(
        runtime.component_host(),
        window_id,
        event,
        value,
    );
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use gpui_components::controls::tab_key_target;

    #[test]
    fn keyboard_navigation_wraps_and_supports_endpoints_and_activation() {
        assert_eq!(tab_key_target("left", 0, 3), Some(2));
        assert_eq!(tab_key_target("right", 2, 3), Some(0));
        assert_eq!(tab_key_target("up", 1, 3), Some(0));
        assert_eq!(tab_key_target("down", 1, 3), Some(2));
        assert_eq!(tab_key_target("home", 2, 3), Some(0));
        assert_eq!(tab_key_target("end", 0, 3), Some(2));
        assert_eq!(tab_key_target("enter", 1, 3), Some(1));
        assert_eq!(tab_key_target("space", 1, 3), Some(1));
        assert_eq!(tab_key_target("tab", 1, 3), None);
        assert_eq!(tab_key_target("right", 0, 0), None);
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: TabsComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let label = node
        .value
        .as_ref()
        .and_then(|value| node.options.iter().find(|option| &option.value == value))
        .map(|option| option.label.clone());

    render_component_fallback(node.style, label, Vec::new(), context)
}
