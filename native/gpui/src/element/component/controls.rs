#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;
use crate::{gpui, ButtonComponentNode, CheckboxComponentNode, ElementRenderContext};

#[cfg(feature = "components")]
pub(crate) fn render_button_component(
    node: ButtonComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, NativeEvent};
    use gpui::{InteractiveElement, IntoElement, ParentElement};
    use gpui_component::{
        button::{Button, ButtonVariants},
        Disableable, Selectable, Sizable,
    };

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let click_event = node.click;
    let clipboard_event = node.clipboard;
    let clipboard_write_event = node.clipboard_write;
    let clipboard_text = node.clipboard_text;
    let file_event = node.file_read;
    let file_prompt = node
        .file_prompt
        .filter(|prompt| !prompt.is_empty())
        .unwrap_or_else(|| "Choose a file".to_string());
    let file_max_bytes = node.file_max_bytes.min(25 * 1_024 * 1_024) as usize;
    let selector = node.id.clone();
    let mut button = Button::new(node.id).debug_selector(|| selector);

    button = match node.variant.as_deref() {
        Some("primary") => button.primary(),
        Some("secondary") => button.secondary(),
        Some("danger") => button.danger(),
        Some("warning") => button.warning(),
        Some("success") => button.success(),
        Some("info") => button.info(),
        Some("ghost") => button.ghost(),
        Some("link") => button.link(),
        Some("text") => button.text(),
        _ => button,
    };

    button = match node.size.as_deref() {
        Some("xs") => button.xsmall(),
        Some("sm") => button.small(),
        Some("lg") => button.large(),
        _ => button,
    };

    button = button
        .disabled(node.disabled)
        .selected(node.selected)
        .loading(node.loading);

    if node.outline {
        button = button.outline();
    }
    if node.compact {
        button = button.compact();
    }
    button = button.label(node.label);
    for child in node.children {
        button = button.child(child.render(context));
    }
    if click_event.is_some()
        || clipboard_event.is_some()
        || clipboard_write_event.is_some()
        || file_event.is_some()
    {
        button = button.on_click(move |_click, window, cx| {
            if let Some(event) = clipboard_write_event.as_ref() {
                if let Some(text) = clipboard_text.as_ref() {
                    cx.write_to_clipboard(gpui::ClipboardItem::new_string(text.clone()));
                    let _ = push_event(
                        &runtime,
                        NativeEvent::ClipboardWrite {
                            window_id,
                            event: event.clone(),
                        },
                    );
                }
            }
            if let Some(event) = clipboard_event.as_ref() {
                let text = super::display::bounded_clipboard_text(
                    cx.read_from_clipboard().and_then(|item| item.text()),
                );
                let _ = push_event(
                    &runtime,
                    NativeEvent::ClipboardRead {
                        window_id,
                        event: event.clone(),
                        payload: crate::TransferPayload {
                            text,
                            external_paths: Vec::new(),
                        },
                    },
                );
            }
            if let Some(event) = file_event.as_ref() {
                super::display::start_file_read(
                    event.clone(),
                    file_prompt.clone(),
                    file_max_bytes,
                    runtime.clone(),
                    window_id,
                    window,
                    cx,
                );
            }
            if let Some(event) = click_event.as_ref() {
                let _ = push_event(
                    &runtime,
                    NativeEvent::Click {
                        window_id,
                        event: event.clone(),
                    },
                );
            }
        });
    }

    apply_component_styles(button, node.style).into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_checkbox_component(
    node: CheckboxComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{InteractiveElement, IntoElement, ParentElement};
    use gpui_component::{checkbox::Checkbox, Disableable, Sizable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let selector = node.id.clone();
    let mut checkbox = Checkbox::new(node.id)
        .debug_selector(|| selector)
        .checked(node.checked)
        .disabled(node.disabled);

    checkbox = match node.size.as_deref() {
        Some("xs") => checkbox.xsmall(),
        Some("sm") => checkbox.small(),
        Some("lg") => checkbox.large(),
        _ => checkbox,
    };

    checkbox = checkbox.label(node.label);
    for child in node.children {
        checkbox = checkbox.child(child.render(context));
    }
    if let Some(event) = node.change {
        checkbox = checkbox.on_click(move |checked, _window, _cx| {
            let _ = push_event(
                &runtime,
                NativeEvent::Input {
                    kind: InputKind::Change,
                    window_id,
                    event: event.clone(),
                    value: Some(EventValue::Boolean(*checked)),
                },
            );
        });
    }

    apply_component_styles(checkbox, node.style).into_any_element()
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::*;

    fn checkbox(checked: bool, disabled: bool) -> crate::ElementNode {
        crate::ElementNode::CheckboxComponent(crate::CheckboxComponentNode {
            style: crate::StyleAttrs::default(),
            id: "notifications".to_string(),
            label: "Notifications".to_string(),
            size: None,
            checked,
            disabled,
            children: Vec::new(),
            change: Some("notifications_changed".to_string()),
        })
    }

    #[gpui::test]
    fn checkbox_click_routes_a_controlled_change_event(cx: &mut gpui::TestAppContext) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            checkbox(false, false),
            gpui::size(gpui::px(240.0), gpui::px(80.0)),
        );

        harness.click_element("notifications");

        assert!(matches!(
            harness.take_events().as_slice(),
            [crate::NativeEvent::Input {
                kind: crate::InputKind::Change,
                window_id: 7,
                event,
                value: Some(crate::EventValue::Boolean(true)),
            }] if event == "notifications_changed"
        ));
    }

    #[gpui::test]
    fn disabled_checkbox_blocks_pointer_activation(cx: &mut gpui::TestAppContext) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            checkbox(false, true),
            gpui::size(gpui::px(240.0), gpui::px(80.0)),
        );

        harness.click_element_at("notifications", gpui::point(gpui::px(2.0), gpui::px(2.0)));

        assert!(harness.take_events().is_empty());
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_button_component(
    node: ButtonComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.label), node.children, context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_checkbox_component(
    node: CheckboxComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.label), node.children, context)
}
