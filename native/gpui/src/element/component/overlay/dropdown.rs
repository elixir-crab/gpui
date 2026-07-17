use crate::{
    gpui, DropdownMenuComponentNode, DropdownMenuItemComponentNode,
    DropdownMenuTriggerComponentNode, ElementRenderContext,
};

#[cfg(feature = "components")]
pub(crate) fn render(
    node: DropdownMenuComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use super::{anchor, request_open, OverlayTrigger};
    use crate::element::{
        component_registry::{ComponentDropdownMenu, ComponentOverlayState},
        controlled::ControlledBinding,
    };
    use gpui::{
        Focusable, InteractiveElement, IntoElement, MouseButton, ParentElement, Role,
        StatefulInteractiveElement,
    };
    use gpui_component::popover::Popover;
    use std::sync::{Arc, Mutex};

    let (trigger, item_nodes) = match dropdown_slots(node.children) {
        Some(slots) => slots,
        None => return super::invalid_slots(),
    };
    let items = item_nodes.iter().map(item_config).collect::<Vec<_>>();

    if context.components.dropdown_menu_mut(&node.id).is_none() {
        let binding = Arc::new(Mutex::new(ControlledBinding::new(
            node.change.clone(),
            node.open,
        )));
        let effective_open = Arc::new(Mutex::new(node.open));
        let trigger_focus = context.cx.focus_handle();
        let select_event = Arc::new(Mutex::new(node.select.clone()));
        let menu = build_menu(
            &items,
            context,
            select_event.clone(),
            binding.clone(),
            effective_open.clone(),
            trigger_focus.clone(),
        );
        let content_focus = menu.focus_handle(context.cx);

        context.components.insert_dropdown_menu(
            &node.id,
            ComponentDropdownMenu {
                overlay: ComponentOverlayState {
                    binding,
                    effective_open,
                    trigger_focus,
                    content_focus,
                },
                menu,
                items: items.clone(),
                select_event,
                rendered_open: false,
            },
        );
    }

    let (force_open, rebuild) = {
        let dropdown = context
            .components
            .dropdown_menu_mut(&node.id)
            .expect("component dropdown menu should exist");

        if let Ok(mut event) = dropdown.select_event.lock() {
            *event = node.select.clone();
        }
        let force_open = dropdown
            .overlay
            .binding
            .lock()
            .map(|mut binding| {
                binding.event = node.change.clone();
                binding.reconcile(&node.open)
            })
            .unwrap_or(true);
        if force_open {
            if let Ok(mut effective_open) = dropdown.overlay.effective_open.lock() {
                *effective_open = node.open;
            }
        }
        let rebuild = (dropdown.items != items).then(|| {
            (
                dropdown.select_event.clone(),
                dropdown.overlay.binding.clone(),
                dropdown.overlay.effective_open.clone(),
                dropdown.overlay.trigger_focus.clone(),
            )
        });
        (force_open, rebuild)
    };

    if let Some((select_event, binding, effective_open, trigger_focus)) = rebuild {
        let menu = build_menu(
            &items,
            context,
            select_event,
            binding,
            effective_open,
            trigger_focus,
        );
        let content_focus = menu.focus_handle(context.cx);
        let dropdown = context
            .components
            .dropdown_menu_mut(&node.id)
            .expect("component dropdown menu should exist");
        dropdown.overlay.content_focus = content_focus;
        dropdown.menu = menu;
        dropdown.items = items;
    }

    let dropdown = context
        .components
        .dropdown_menu_mut(&node.id)
        .expect("component dropdown menu should exist");
    let open = dropdown
        .overlay
        .effective_open
        .lock()
        .map(|open| *open)
        .unwrap_or(node.open);

    if dropdown.rendered_open != open {
        if !open {
            let focus = dropdown.overlay.trigger_focus.clone();
            context
                .window
                .defer(context.cx, move |window, cx| focus.focus(window, cx));
        }
        dropdown.rendered_open = open;
    }

    let binding = dropdown.overlay.binding.clone();
    let effective_open = dropdown.overlay.effective_open.clone();
    let trigger_focus = dropdown.overlay.trigger_focus.clone();
    let menu = dropdown.menu.clone();
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let trigger_runtime = runtime.clone();
    let trigger_binding = binding.clone();
    let trigger_effective_open = effective_open.clone();
    let mouse_focus = trigger_focus.clone();
    let disabled = node.disabled;

    let trigger_element = gpui::div()
        .id(format!("{}-trigger", node.id))
        .role(Role::Button)
        .aria_expanded(open)
        .track_focus(&trigger_focus.clone().tab_stop(!disabled))
        .on_mouse_down(MouseButton::Left, move |_event, window, cx| {
            if disabled {
                cx.stop_propagation();
                return;
            }
            mouse_focus.focus(window, cx);
        })
        .on_key_down(move |event, _window, cx| {
            if disabled || !matches!(event.keystroke.key.as_str(), "enter" | "space" | "down") {
                return;
            }
            request_open(
                &trigger_runtime,
                window_id,
                &trigger_binding,
                &trigger_effective_open,
                true,
                false,
            );
            cx.stop_propagation();
        })
        .child(super::render_dropdown_menu_trigger(trigger, context));

    let callback_runtime = runtime;
    let callback_binding = binding;
    let callback_effective_open = effective_open;
    let mut element = Popover::new(node.id)
        .appearance(false)
        .overlay_closable(false)
        .anchor(anchor(node.anchor.as_deref()))
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
        .content(move |_state, window, cx| {
            menu.focus_handle(cx).focus(window, cx);
            menu.clone()
        });
    if force_open {
        element = element.open(open);
    }

    super::super::apply_component_styles(element, node.style).into_any_element()
}

#[cfg(feature = "components")]
fn build_menu(
    items: &[super::super::super::component_registry::DropdownMenuItemConfig],
    context: &mut ElementRenderContext<'_, '_>,
    select_event: super::super::super::component_registry::SharedEvent,
    binding: super::super::super::controlled::SharedBinding<bool>,
    effective_open: std::sync::Arc<std::sync::Mutex<bool>>,
    trigger_focus: gpui::FocusHandle,
) -> gpui::Entity<gpui_component::menu::PopupMenu> {
    use gpui::DismissEvent;
    use gpui_component::menu::{PopupMenu, PopupMenuItem};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let menu_items = items.to_vec();
    let menu_binding = binding.clone();
    let menu_effective_open = effective_open.clone();
    let menu = PopupMenu::build(context.window, context.cx, move |mut menu, _window, _cx| {
        menu = menu.action_context(trigger_focus.clone());
        for item in &menu_items {
            let item_runtime = runtime.clone();
            let item_select_event = select_event.clone();
            let item_binding = menu_binding.clone();
            let item_effective_open = menu_effective_open.clone();
            let value = item.value.clone();
            menu = menu.item(
                PopupMenuItem::new(item.label.clone())
                    .disabled(item.disabled)
                    .checked(item.checked)
                    .on_click(move |_event, _window, _cx| {
                        request_close(
                            &item_runtime,
                            window_id,
                            &item_binding,
                            &item_effective_open,
                        );
                        emit_select(&item_runtime, window_id, &item_select_event, value.clone());
                    }),
            );
        }
        menu
    });

    let dismiss_runtime = context.runtime.clone();
    let dismiss_binding = binding;
    let dismiss_effective_open = effective_open;
    context
        .window
        .subscribe(
            &menu,
            context.cx,
            move |_, _: &DismissEvent, _window, _cx| {
                request_close(
                    &dismiss_runtime,
                    window_id,
                    &dismiss_binding,
                    &dismiss_effective_open,
                );
            },
        )
        .detach();
    menu
}

#[cfg(feature = "components")]
fn emit_select(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: &super::super::super::component_registry::SharedEvent,
    value: String,
) {
    use crate::{push_event, EventValue, InputKind, NativeEvent};

    let event = event.lock().ok().and_then(|event| event.clone());
    if let Some(event) = event {
        let _ = push_event(
            runtime,
            NativeEvent::Input {
                kind: InputKind::Select,
                window_id,
                event,
                value: Some(EventValue::String(value)),
            },
        );
    }
}

#[cfg(feature = "components")]
fn request_close(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    binding: &super::super::super::controlled::SharedBinding<bool>,
    effective_open: &std::sync::Arc<std::sync::Mutex<bool>>,
) {
    let should_close = effective_open.lock().map(|open| *open).unwrap_or(true);
    if should_close {
        super::request_open(runtime, window_id, binding, effective_open, false, true);
    }
}

fn dropdown_slots(
    children: Vec<crate::ElementNode>,
) -> Option<(
    DropdownMenuTriggerComponentNode,
    Vec<DropdownMenuItemComponentNode>,
)> {
    let mut trigger = None;
    let mut items = Vec::new();
    for child in children {
        match child {
            crate::ElementNode::DropdownMenuTriggerComponent(node) if trigger.is_none() => {
                trigger = Some(node);
            }
            crate::ElementNode::DropdownMenuItemComponent(node) => items.push(node),
            _other => return None,
        }
    }
    if items.is_empty() {
        return None;
    }
    Some((trigger?, items))
}

#[cfg(feature = "components")]
fn item_config(
    item: &DropdownMenuItemComponentNode,
) -> super::super::super::component_registry::DropdownMenuItemConfig {
    super::super::super::component_registry::DropdownMenuItemConfig {
        value: item.value.clone(),
        label: item.label.clone(),
        disabled: item.disabled,
        checked: item.checked,
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: DropdownMenuComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    let (trigger, items) = match dropdown_slots(node.children) {
        Some(slots) => slots,
        None => return super::invalid_slots(),
    };
    let mut element = crate::apply_generated_render_styles(gpui::div(), node.style)
        .child(super::render_dropdown_menu_trigger(trigger, context));
    for item in items {
        element = element.child(item.label);
    }
    element.into_any_element()
}
