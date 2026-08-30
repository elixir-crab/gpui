use crate::element::ElementRenderContext;
use crate::{gpui, SwitchComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement};

    let checked = node.checked;
    let change_event = node.change.clone();
    let key_host = context.runtime.component_host().clone();
    let window_id = context.window_id;
    let owner = crate::switch_to_owner(node);
    let rendered = gpui_components::switch::render(
        owner,
        &mut gpui_components::switch::SwitchRenderContext {
            window_id,
            host: context.runtime.component_host().clone(),
            window: context.window,
            cx: context.cx,
        },
    );
    let focus_handle = rendered.focus_handle;
    let unavailable = rendered.unavailable;
    let switch_id = rendered.id;
    let element = gpui::div().id(switch_id.clone()).child(rendered.element);

    crate::element::register_test_target(element, switch_id, Some(focus_handle.clone()), context)
        .role(Role::Switch)
        .aria_label(rendered.label)
        .aria_toggled(if checked {
            gpui::Toggled::True
        } else {
            gpui::Toggled::False
        })
        .track_focus(&focus_handle.tab_stop(!unavailable))
        .on_key_down(move |event, _window, cx| {
            if unavailable || !matches!(event.keystroke.key.as_str(), "enter" | "space") {
                return;
            }
            gpui_components::switch::emit_change(
                &key_host,
                window_id,
                change_event.as_ref(),
                !checked,
            );
            cx.stop_propagation();
        })
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.label), Vec::new(), context)
}
