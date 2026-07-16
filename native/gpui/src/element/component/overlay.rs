use crate::{
    gpui, ElementRenderContext, PopoverComponentNode, PopoverContentComponentNode,
    PopoverTriggerComponentNode, TooltipComponentNode, TooltipTriggerComponentNode,
};

#[cfg(feature = "components")]
pub(super) fn render_tooltip(
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
pub(super) fn render_tooltip(
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

pub(super) fn render_tooltip_trigger(
    node: TooltipTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

#[cfg(feature = "components")]
pub(super) fn render(
    node: PopoverComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use super::super::component_registry::ComponentPopover;
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
                binding: Arc::new(Mutex::new(ControlledBinding::new(
                    node.change.clone(),
                    node.open,
                ))),
                effective_open: Arc::new(Mutex::new(node.open)),
                trigger_focus: context.cx.focus_handle(),
                content_focus: context.cx.focus_handle(),
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
        .binding
        .lock()
        .map(|mut binding| {
            binding.event = node.change.clone();
            binding.reconcile(&node.open)
        })
        .unwrap_or(true);
    if force_open {
        if let Ok(mut effective_open) = popover.effective_open.lock() {
            *effective_open = node.open;
        }
    }
    let open = popover
        .effective_open
        .lock()
        .map(|open| *open)
        .unwrap_or(node.open);

    if popover.rendered_open != open {
        if open {
            if !popover
                .content_focus
                .contains_focused(context.window, context.cx)
            {
                popover.previous_focus = context.window.focused(context.cx);
                popover.content_focus.focus(context.window, context.cx);
            }
        } else if popover
            .content_focus
            .contains_focused(context.window, context.cx)
        {
            popover
                .previous_focus
                .take()
                .unwrap_or_else(|| popover.trigger_focus.clone())
                .focus(context.window, context.cx);
        }
        popover.rendered_open = open;
    }

    let binding = popover.binding.clone();
    let effective_open = popover.effective_open.clone();
    let trigger_focus = popover.trigger_focus.clone();
    let content_focus = popover.content_focus.clone();
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

pub(super) fn render_trigger(
    node: PopoverTriggerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
}

pub(super) fn render_content(
    node: PopoverContentComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_slot(node.style, node.children, context)
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
pub(super) fn render(
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
