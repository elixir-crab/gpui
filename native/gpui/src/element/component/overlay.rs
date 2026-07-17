pub(crate) mod dropdown;

use crate::{
    gpui, DialogComponentNode, DialogContentComponentNode, DialogTriggerComponentNode,
    ElementRenderContext, PopoverComponentNode, PopoverContentComponentNode,
    PopoverTriggerComponentNode, TooltipComponentNode, TooltipTriggerComponentNode,
};

#[cfg(feature = "components")]
pub(crate) fn render_dialog(
    node: DialogComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use super::super::component_registry::{ComponentDialog, ComponentOverlayState, DialogConfig};
    use super::super::controlled::ControlledBinding;
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
        let content_state = Arc::new(crate::WindowState::new(content_tree.clone()));
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
                        title: None,
                        width: 448.0,
                        overlay: true,
                        closable: true,
                        keyboard: true,
                        close_button: true,
                        style: crate::StyleAttrs::default(),
                    });
                let mut dialog = super::apply_component_styles(dialog, config.style)
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
                if let Some(title) = config.title {
                    dialog = dialog.title(title);
                }
                dialog
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
        element = element.child(
            gpui::div()
                .id("trigger")
                .role(Role::Button)
                .aria_expanded(open)
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
        children: content.children,
        click: None,
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

#[cfg(feature = "components")]
pub(crate) fn render_tooltip(
    node: TooltipComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};
    use gpui_component::tooltip::Tooltip;
    use std::time::Duration;

    let trigger = match tooltip_trigger(node.children) {
        Some(trigger) => trigger,
        None => return invalid_slots(),
    };
    let text: gpui::SharedString = node.text.into();
    let tooltip_text = text.clone();
    let mut element = crate::apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .child(render_tooltip_trigger(trigger, context));
    element = if node.hoverable {
        element.hoverable_tooltip(move |window, cx| {
            Tooltip::new(tooltip_text.clone()).build(window, cx)
        })
    } else {
        element.tooltip(move |window, cx| Tooltip::new(text.clone()).build(window, cx))
    };

    let delay = if node.delay.is_finite() {
        node.delay.clamp(0.0, 60_000.0)
    } else {
        500.0
    };
    element
        .tooltip_show_delay(Duration::from_secs_f64(delay / 1000.0))
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_tooltip(
    node: TooltipComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    match tooltip_trigger(node.children) {
        Some(trigger) => render_tooltip_trigger(trigger, context),
        None => invalid_slots(),
    }
}

fn tooltip_trigger(children: Vec<crate::ElementNode>) -> Option<TooltipTriggerComponentNode> {
    let mut children = children.into_iter();
    match (children.next(), children.next()) {
        (Some(crate::ElementNode::TooltipTriggerComponent(trigger)), None) => Some(trigger),
        _other => None,
    }
}

pub(crate) fn render_tooltip_trigger(
    node: TooltipTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: PopoverComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use super::super::component_registry::{ComponentOverlayState, ComponentPopover};
    use super::super::controlled::ControlledBinding;
    use gpui::{
        InteractiveElement, IntoElement, MouseButton, ParentElement, Role,
        StatefulInteractiveElement,
    };
    use gpui_component::popover::Popover;
    use std::sync::{Arc, Mutex};

    let (trigger, content) = match popover_slots(node.children) {
        Some(slots) => slots,
        None => return invalid_slots(),
    };

    if context.components.popover_mut(&node.id).is_none() {
        context.components.insert_popover(
            &node.id,
            ComponentPopover {
                overlay: ComponentOverlayState {
                    binding: Arc::new(Mutex::new(ControlledBinding::new(
                        node.change.clone(),
                        node.open,
                    ))),
                    effective_open: Arc::new(Mutex::new(node.open)),
                    trigger_focus: context.cx.focus_handle(),
                    content_focus: context.cx.focus_handle(),
                },
                previous_focus: None,
                rendered_open: node.open,
            },
        );
    }

    let popover = context
        .components
        .popover_mut(&node.id)
        .expect("component popover should exist");
    let force_open = popover
        .overlay
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.open)
        })
        .unwrap_or(true);
    if force_open {
        if let Ok(mut effective_open) = popover.overlay.effective_open.lock() {
            *effective_open = node.open;
        }
    }
    let open = popover
        .overlay
        .effective_open
        .lock()
        .map(|open| *open)
        .unwrap_or(node.open);

    if popover.rendered_open != open {
        if open {
            if !popover
                .overlay
                .content_focus
                .contains_focused(context.window, context.cx)
            {
                popover.previous_focus = context.window.focused(context.cx);
                popover
                    .overlay
                    .content_focus
                    .focus(context.window, context.cx);
            }
        } else if popover
            .overlay
            .content_focus
            .contains_focused(context.window, context.cx)
        {
            popover
                .previous_focus
                .take()
                .unwrap_or_else(|| popover.overlay.trigger_focus.clone())
                .focus(context.window, context.cx);
        }
        popover.rendered_open = open;
    }

    let binding = popover.overlay.binding.clone();
    let effective_open = popover.overlay.effective_open.clone();
    let trigger_focus = popover.overlay.trigger_focus.clone();
    let content_focus = popover.overlay.content_focus.clone();
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let trigger_runtime = runtime.clone();
    let trigger_binding = binding.clone();
    let trigger_effective_open = effective_open.clone();
    let mouse_focus = trigger_focus.clone();
    let trigger_element = gpui::div()
        .id(format!("{}-trigger", node.id))
        .role(Role::Button)
        .aria_expanded(open)
        .track_focus(&trigger_focus.tab_stop(true))
        .on_mouse_down(MouseButton::Left, move |_event, window, cx| {
            mouse_focus.focus(window, cx);
        })
        .on_key_down(move |event, _window, cx| {
            if !matches!(event.keystroke.key.as_str(), "enter" | "space") {
                return;
            }
            request_open(
                &trigger_runtime,
                window_id,
                &trigger_binding,
                &trigger_effective_open,
                !open,
                false,
            );
            cx.stop_propagation();
        })
        .child(render_trigger(trigger, context));

    let content_element = gpui::div()
        .track_focus(&content_focus)
        .child(render_content(content, context));
    let callback_runtime = runtime;
    let callback_binding = binding;
    let callback_effective_open = effective_open;
    let mut element = Popover::new(node.id)
        .anchor(anchor(node.anchor.as_deref()))
        .appearance(node.appearance)
        .overlay_closable(node.closable)
        .track_focus(&content_focus)
        .trigger(OverlayTrigger::new(trigger_element.into_any_element()))
        .on_open_change(move |open, _window, _cx| {
            request_open(
                &callback_runtime,
                window_id,
                &callback_binding,
                &callback_effective_open,
                *open,
                true,
            );
        })
        .child(content_element);
    if force_open {
        element = element.open(open);
    }

    super::apply_component_styles(element, node.style).into_any_element()
}

#[cfg(feature = "components")]
fn request_open(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    binding: &super::super::controlled::SharedBinding<bool>,
    effective_open: &std::sync::Arc<std::sync::Mutex<bool>>,
    open: bool,
    native_applied: bool,
) {
    use crate::{push_event, EventValue, InputKind, NativeEvent};

    if let Ok(mut value) = effective_open.lock() {
        *value = open;
    }
    let event = binding.lock().ok().and_then(|mut binding| {
        binding.event.clone().inspect(|_event| {
            if native_applied {
                binding.push_pending(open);
            }
        })
    });
    let Some(event) = event else {
        return;
    };
    let result = push_event(
        runtime,
        NativeEvent::Input {
            kind: InputKind::Change,
            window_id,
            event,
            value: Some(EventValue::Boolean(open)),
        },
    );
    if result.is_err() && native_applied {
        if let Ok(mut binding) = binding.lock() {
            binding.pop_pending();
        }
    }
}

#[cfg(feature = "components")]
fn anchor(anchor: Option<&str>) -> gpui::Anchor {
    match anchor {
        Some("top_center") => gpui::Anchor::TopCenter,
        Some("top_right") => gpui::Anchor::TopRight,
        Some("bottom_left") => gpui::Anchor::BottomLeft,
        Some("bottom_center") => gpui::Anchor::BottomCenter,
        Some("bottom_right") => gpui::Anchor::BottomRight,
        Some("left_center") => gpui::Anchor::LeftCenter,
        Some("right_center") => gpui::Anchor::RightCenter,
        _other => gpui::Anchor::TopLeft,
    }
}

#[cfg(feature = "components")]
struct OverlayTrigger {
    element: gpui::AnyElement,
    selected: bool,
}

#[cfg(feature = "components")]
impl OverlayTrigger {
    fn new(element: gpui::AnyElement) -> Self {
        Self {
            element,
            selected: false,
        }
    }
}

#[cfg(feature = "components")]
impl gpui_component::Selectable for OverlayTrigger {
    fn selected(mut self, selected: bool) -> Self {
        self.selected = selected;
        self
    }

    fn is_selected(&self) -> bool {
        self.selected
    }
}

#[cfg(feature = "components")]
impl gpui::IntoElement for OverlayTrigger {
    type Element = gpui::AnyElement;

    fn into_element(self) -> Self::Element {
        self.element
    }
}

fn popover_slots(
    children: Vec<crate::ElementNode>,
) -> Option<(PopoverTriggerComponentNode, PopoverContentComponentNode)> {
    let mut trigger = None;
    let mut content = None;

    for child in children {
        match child {
            crate::ElementNode::PopoverTriggerComponent(node) if trigger.is_none() => {
                trigger = Some(node);
            }
            crate::ElementNode::PopoverContentComponent(node) if content.is_none() => {
                content = Some(node);
            }
            _other => return None,
        }
    }

    Some((trigger?, content?))
}

pub(crate) fn render_trigger(
    node: PopoverTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

pub(crate) fn render_content(
    node: PopoverContentComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

pub(crate) fn render_dropdown_menu_trigger(
    node: crate::DropdownMenuTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

pub(crate) fn render_dropdown_menu_item(
    node: crate::DropdownMenuItemComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    crate::apply_generated_render_styles(gpui::div(), node.style)
        .child(node.label)
        .into_any_element()
}

fn render_slot(
    style: crate::StyleAttrs,
    children: Vec<crate::ElementNode>,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    let mut element = crate::apply_generated_render_styles(gpui::div(), style);
    for child in children {
        element = element.child(child.render(context));
    }
    element.into_any_element()
}

fn invalid_slots() -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    gpui::div()
        .child("invalid popover slots")
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: PopoverComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let (trigger, content) = match popover_slots(node.children) {
        Some(slots) => slots,
        None => return invalid_slots(),
    };

    let children = vec![
        render_trigger(trigger, context),
        render_content(content, context),
    ];
    use gpui::{IntoElement, ParentElement};
    let mut element = crate::apply_generated_render_styles(gpui::div(), node.style);
    for child in children {
        element = element.child(child);
    }
    element.into_any_element()
}
