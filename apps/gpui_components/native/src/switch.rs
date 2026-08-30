use crate::host::ComponentHost;
use crate::host_contract::{ComponentEvent, ComponentValue, ComponentValueEvent};
use zed_gpui as gpui;

#[derive(Clone, Debug, PartialEq)]
pub struct SwitchNode {
    pub id: String,
    pub label: String,
    pub checked: bool,
    pub disabled: bool,
    pub loading: bool,
    pub size: Option<String>,
    pub change: Option<String>,
}

pub struct SwitchRenderContext<'a> {
    pub window_id: u64,
    pub host: ComponentHost,
    pub window: &'a mut gpui::Window,
    pub cx: &'a mut gpui::App,
}

pub struct RenderedSwitch {
    pub element: gpui::AnyElement,
    pub focus_handle: gpui::FocusHandle,
    pub unavailable: bool,
    pub label: String,
    pub id: String,
}

pub fn render(node: SwitchNode, context: &mut SwitchRenderContext<'_>) -> RenderedSwitch {
    use gpui::{IntoElement, ParentElement, Styled};
    use gpui_component::{h_flex, spinner::Spinner, switch::Switch, Disableable, Sizable};

    let checked = node.checked;
    let unavailable = node.disabled || node.loading;
    let focus_handle = context
        .window
        .use_keyed_state(format!("{}-focus", node.id), context.cx, |_, cx| {
            cx.focus_handle()
        })
        .read(context.cx)
        .clone();
    let mouse_focus = focus_handle.clone();
    let mouse_host = context.host.clone();
    let change_event = node.change.clone();
    let window_id = context.window_id;
    let mut element = Switch::new(node.id.clone())
        .checked(checked)
        .disabled(unavailable)
        .on_click(move |checked, window, cx| {
            mouse_focus.focus(window, cx);
            emit_change(&mouse_host, window_id, change_event.as_ref(), *checked);
        });
    element = element.label(node.label.clone());
    element = match node.size.as_deref() {
        Some("xs") => element.xsmall(),
        Some("sm") => element.small(),
        Some("lg") => element.large(),
        _ => element,
    };
    let mut content = h_flex().items_center().gap_2().child(element);
    if node.loading {
        let spinner = match node.size.as_deref() {
            Some("xs") => Spinner::new().xsmall(),
            Some("lg") => Spinner::new().large(),
            _ => Spinner::new().small(),
        };
        content = content.child(spinner);
    }

    RenderedSwitch {
        element: content.into_any_element(),
        focus_handle,
        unavailable,
        label: node.label,
        id: node.id,
    }
}

pub fn emit_change(host: &ComponentHost, window_id: u64, event: Option<&String>, value: bool) {
    let Some(event) = event else {
        return;
    };
    let _ = host.emit(ComponentEvent::Change(ComponentValueEvent {
        envelope: crate::host_contract::ComponentEventEnvelope {
            window_id,
            event: event.clone(),
        },
        value: ComponentValue::Boolean(value),
    }));
}
