use crate::element::ElementRenderContext;
use crate::{gpui, SwitchComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
        Toggled,
    };
    use gpui_component::{h_flex, spinner::Spinner, switch::Switch, Disableable, Sizable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let key_runtime = runtime.clone();
    let key_event = change_event.clone();
    let checked = node.checked;
    let unavailable = node.disabled || node.loading;
    let switch_id = node.id.clone();
    let focus_handle = context
        .window
        .use_keyed_state(format!("{}-focus", node.id), context.cx, |_, cx| {
            cx.focus_handle()
        })
        .read(context.cx)
        .clone();
    let mouse_focus = focus_handle.clone();
    let mut element = Switch::new(switch_id)
        .checked(checked)
        .disabled(unavailable)
        .on_click(move |checked, window, cx| {
            mouse_focus.focus(window, cx);
            emit_change(&runtime, window_id, change_event.as_ref(), *checked);
        });
    if let Some(label) = node.label {
        element = element.label(label);
    }
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

    gpui::div()
        .id(node.id)
        .role(Role::Switch)
        .aria_toggled(if checked {
            Toggled::True
        } else {
            Toggled::False
        })
        .track_focus(&focus_handle.tab_stop(!unavailable))
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

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: SwitchComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, Vec::new(), context)
}
