#[cfg(feature = "components")]
use super::request_open;
use super::{invalid_slots, render_slot};
use crate::{
    gpui, DialogComponentNode, DialogContentComponentNode, DialogTriggerComponentNode,
    ElementRenderContext,
};

#[cfg(feature = "components")]
pub(crate) fn render_dialog(
    node: DialogComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::component_registry::{
        ComponentDialog, ComponentOverlayState, DialogConfig,
    };
    use crate::element::controlled::ControlledBinding;
    use gpui::{
        AppContext, InteractiveElement, IntoElement, MouseButton, ParentElement, Role,
        StatefulInteractiveElement,
    };
    use gpui_component::WindowExt;
    use std::sync::{Arc, Mutex};

    let (trigger, content) = match dialog_slots(node.children) {
        Some(slots) => slots,
        None => return invalid_slots(),
    };
    let content_tree = dialog_content_tree(content);

    if context.components.dialog_mut(&node.id).is_none() {
        let content_state = Arc::new(crate::WindowState::new(content_tree.clone(), Vec::new()));
        let binding = Arc::new(Mutex::new(ControlledBinding::new(
            node.change.clone(),
            node.open,
        )));
        let effective_open = Arc::new(Mutex::new(node.open));
        let opened = Arc::new(Mutex::new(false));
        let keyboard = Arc::new(Mutex::new(node.keyboard));
        let content_focus = context.cx.focus_handle();
        let config = Arc::new(Mutex::new(DialogConfig {
            title: node.title.clone(),
            width: node.width.clamp(1.0, 4096.0) as f32,
            overlay: node.overlay,
            closable: node.closable,
            keyboard: node.keyboard,
            close_button: node.close_button,
            style: node.style.clone(),
        }));
        let key_runtime = context.runtime.clone();
        let key_binding = binding.clone();
        let key_effective_open = effective_open.clone();
        let key_opened = opened.clone();
        let key_keyboard = keyboard.clone();
        let window_id = context.window_id;
        let key_handler = Arc::new(
            move |event: &gpui::KeyDownEvent, window: &mut gpui::Window, cx: &mut gpui::App| {
                let keyboard = key_keyboard.lock().map(|enabled| *enabled).unwrap_or(true);
                if keyboard && event.keystroke.key == "escape" {
                    if let Ok(mut state) = key_opened.lock() {
                        *state = false;
                    }
                    request_open(
                        &key_runtime,
                        window_id,
                        &key_binding,
                        &key_effective_open,
                        false,
                        true,
                    );
                    window.close_dialog(cx);
                    cx.stop_propagation();
                }
            },
        );
        let content_state_for_view = content_state.clone();
        let content_runtime = context.runtime.clone();
        let content_focus_for_view = content_focus.clone();
        let content_view = context.cx.new(move |_cx| {
            crate::ElixirRoot::new_dialog(
                content_state_for_view,
                content_runtime,
                window_id,
                content_focus_for_view,
                key_handler,
            )
        });
        context.components.insert_dialog(
            &node.id,
            ComponentDialog {
                overlay: ComponentOverlayState {
                    binding,
                    effective_open,
                    trigger_focus: context.cx.focus_handle(),
                    content_focus,
                },
                opened,
                keyboard,
                config,
                content: content_view,
                content_state,
            },
        );
    }

    let dialog = context
        .components
        .dialog_mut(&node.id)
        .expect("component dialog should exist");
    if let Ok(mut tree) = dialog.content_state.tree.lock() {
        *tree = content_tree;
    }
    if let Ok(mut keyboard) = dialog.keyboard.lock() {
        *keyboard = node.keyboard;
    }
    if let Ok(mut config) = dialog.config.lock() {
        *config = DialogConfig {
            title: node.title.clone(),
            width: node.width.clamp(1.0, 4096.0) as f32,
            overlay: node.overlay,
            closable: node.closable,
            keyboard: node.keyboard,
            close_button: node.close_button,
            style: node.style.clone(),
        };
    }
    let force_open = dialog
        .overlay
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.open)
        })
        .unwrap_or(true);
    if force_open {
        if let Ok(mut effective_open) = dialog.overlay.effective_open.lock() {
            *effective_open = node.open;
        }
    }
    let open = dialog
        .overlay
        .effective_open
        .lock()
        .map(|open| *open)
        .unwrap_or(node.open);
    let was_open = dialog.opened.lock().map(|opened| *opened).unwrap_or(false);

    let binding = dialog.overlay.binding.clone();
    let effective_open = dialog.overlay.effective_open.clone();
    let opened = dialog.opened.clone();
    let trigger_focus = dialog.overlay.trigger_focus.clone();
    let content_focus = dialog.overlay.content_focus.clone();
    let content_view = dialog.content.clone();
    let config = dialog.config.clone();
    let runtime = context.runtime.clone();
    let window_id = context.window_id;

    if open && !was_open {
        if let Ok(mut state) = opened.lock() {
            *state = true;
        }
        let callback_runtime = runtime.clone();
        let callback_binding = binding.clone();
        let callback_effective_open = effective_open.clone();
        let callback_opened = opened.clone();
        context.window.defer(context.cx, move |window, cx| {
            let content_view = content_view.clone();
            let callback_runtime = callback_runtime.clone();
            let callback_binding = callback_binding.clone();
            let callback_effective_open = callback_effective_open.clone();
            let callback_opened = callback_opened.clone();
            let config = config.clone();
            window.open_dialog(cx, move |dialog, _window, _cx| {
                let config = config
                    .lock()
                    .map(|config| config.clone())
                    .unwrap_or(DialogConfig {
                        title: "Dialog".to_string(),
                        width: 448.0,
                        overlay: true,
                        closable: true,
                        keyboard: true,
                        close_button: true,
                        style: crate::StyleAttrs::default(),
                    });
                let dialog = super::super::apply_component_styles(dialog, config.style)
                    .width(gpui::px(config.width))
                    .overlay(config.overlay)
                    .overlay_closable(config.closable)
                    .keyboard(config.keyboard)
                    .close_button(config.close_button)
                    .on_close({
                        let runtime = callback_runtime.clone();
                        let binding = callback_binding.clone();
                        let effective_open = callback_effective_open.clone();
                        let opened = callback_opened.clone();
                        move |_event, _window, _cx| {
                            if let Ok(mut state) = opened.lock() {
                                *state = false;
                            }
                            request_open(
                                &runtime,
                                window_id,
                                &binding,
                                &effective_open,
                                false,
                                true,
                            );
                        }
                    })
                    .child(content_view.clone());
                dialog.title(config.title)
            });
            window.defer(cx, move |window, cx| content_focus.focus(window, cx));
        });
    } else if !open && was_open {
        if let Ok(mut state) = opened.lock() {
            *state = false;
        }
        context.window.defer(context.cx, move |window, cx| {
            window.close_dialog(cx);
        });
    }

    let mut element = gpui::div().id(node.id);
    if let Some(trigger) = trigger {
        let trigger_runtime = runtime.clone();
        let trigger_binding = binding.clone();
        let trigger_effective_open = effective_open.clone();
        let key_runtime = runtime;
        let key_binding = binding;
        let key_effective_open = effective_open;
        let mouse_focus = trigger_focus.clone();
        let accessibility = super::overlay_trigger_accessibility(node.title.clone(), open);
        element = element.child(
            gpui::div()
                .id("trigger")
                .role(Role::Button)
                .aria_label(accessibility.label)
                .aria_expanded(accessibility.expanded)
                .track_focus(&trigger_focus.tab_stop(true))
                .on_mouse_down(MouseButton::Left, move |_event, window, cx| {
                    mouse_focus.focus(window, cx);
                    request_open(
                        &trigger_runtime,
                        window_id,
                        &trigger_binding,
                        &trigger_effective_open,
                        true,
                        false,
                    );
                })
                .on_key_down(move |event, _window, cx| {
                    if !matches!(event.keystroke.key.as_str(), "enter" | "space") {
                        return;
                    }
                    request_open(
                        &key_runtime,
                        window_id,
                        &key_binding,
                        &key_effective_open,
                        true,
                        false,
                    );
                    cx.stop_propagation();
                })
                .child(render_dialog_trigger(trigger, context)),
        );
    }

    element.into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_dialog(
    node: DialogComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let (trigger, content) = match dialog_slots(node.children) {
        Some(slots) => slots,
        None => return invalid_slots(),
    };
    use gpui::{IntoElement, ParentElement};
    let mut element = crate::apply_generated_render_styles(gpui::div(), node.style);
    if let Some(trigger) = trigger {
        element = element.child(render_dialog_trigger(trigger, context));
    }
    element
        .child(render_dialog_content(content, context))
        .into_any_element()
}

fn dialog_slots(
    children: Vec<crate::ElementNode>,
) -> Option<(
    Option<DialogTriggerComponentNode>,
    DialogContentComponentNode,
)> {
    let mut trigger = None;
    let mut content = None;
    for child in children {
        match child {
            crate::ElementNode::DialogTriggerComponent(node) if trigger.is_none() => {
                trigger = Some(node);
            }
            crate::ElementNode::DialogContentComponent(node) if content.is_none() => {
                content = Some(node);
            }
            _other => return None,
        }
    }
    Some((trigger, content?))
}

#[cfg(feature = "components")]
fn dialog_content_tree(content: DialogContentComponentNode) -> crate::ElementNode {
    crate::ElementNode::Div(crate::ContainerNode {
        tag: crate::GeneratedElementTag::Div,
        style: content.style,
        id: None,
        accessibility: crate::AccessibilitySemantics::default(),
        children: content.children,
        click: None,
        bounds_change: None,
        focus_request: 0,
        focus: None,
        blur: None,
    })
}

pub(crate) fn render_dialog_trigger(
    node: DialogTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

pub(crate) fn render_dialog_content(
    node: DialogContentComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}
