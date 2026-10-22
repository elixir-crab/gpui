use crate::{gpui, ContextMenuComponentNode, ElementRenderContext};

/// A secondary click on the content opens a menu at the pointer, drawn after
/// Zed's context menus: compact rows, a light shadow, and one highlight that
/// follows both the pointer and the arrow keys. Choosing an item reports its
/// value through `phx-select`. Primary clicks still reach the content.
#[cfg(feature = "components")]
pub(crate) fn render(
    node: ContextMenuComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use crate::{push_event, ElementNode, EventValue, InputKind, NativeEvent};
    use gpui::prelude::FluentBuilder;
    use gpui::{
        anchored, deferred, div, hsla, point, px, BoxShadow, InteractiveElement, IntoElement,
        MouseButton, ParentElement, Role, StatefulInteractiveElement, Styled,
    };
    use gpui_component::{ActiveTheme, Icon, IconName};
    use std::rc::Rc;

    let mut items = Vec::new();
    let mut content = Vec::new();
    for child in node.children {
        match child {
            ElementNode::DropdownMenuItemComponent(item) => items.push(item),
            other => content.push(other.render(context)),
        }
    }

    let menu =
        context
            .window
            .use_keyed_state(format!("{}-context-menu", node.id), context.cx, |_, cx| {
                MenuState {
                    position: None,
                    highlighted: None,
                    focus: cx.focus_handle(),
                }
            });
    let MenuState {
        position,
        highlighted,
        focus,
    } = menu.read(context.cx).clone();

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let select = node.select;
    let values = items
        .iter()
        .map(|item| item.value.clone())
        .collect::<Vec<_>>();
    let enabled = items.iter().map(|item| !item.disabled).collect::<Vec<_>>();

    // Choosing closes the menu before reporting the value.
    let choose: Rc<dyn Fn(usize, &mut gpui::App)> = {
        let menu = menu.clone();
        Rc::new(move |index, cx| {
            menu.update(cx, |menu, cx| menu.close(cx));
            if let Some(event) = select.clone() {
                let _ = push_event(
                    &runtime,
                    NativeEvent::Input {
                        kind: InputKind::Select,
                        window_id,
                        event,
                        value: Some(EventValue::String(values[index].clone())),
                    },
                );
            }
        })
    };

    let mut element = apply_generated_render_styles(div(), node.style)
        .id(node.id.clone())
        .children(content)
        .on_mouse_down(MouseButton::Right, {
            let menu = menu.clone();
            let focus = focus.clone();
            move |event, window, cx| {
                menu.update(cx, |menu, cx| {
                    menu.position = Some(event.position);
                    menu.highlighted = None;
                    cx.notify();
                });
                focus.focus(window, cx);
                cx.stop_propagation();
            }
        });

    if let Some(position) = position {
        let theme = context.cx.theme();
        let highlight = theme.secondary_hover;
        let any_checked = items.iter().any(|item| item.checked);

        let rows = items
            .into_iter()
            .enumerate()
            .map(|(index, item)| {
                let row = div()
                    .id(("context-menu-item", index))
                    .role(Role::MenuItem)
                    .flex()
                    .items_center()
                    .gap(px(6.))
                    .h(px(22.))
                    .px(px(6.))
                    .rounded(px(4.))
                    .when(any_checked, |row| {
                        row.child(div().w(px(14.)).when(item.checked, |slot| {
                            slot.child(Icon::new(IconName::Check).size(px(14.)))
                        }))
                    })
                    .child(item.label);

                let row = if item.disabled {
                    row.text_color(theme.muted_foreground)
                } else {
                    let menu = menu.clone();
                    let choose = choose.clone();
                    row.when(highlighted == Some(index), |row| row.bg(highlight))
                        .on_hover(move |hovered, _window, cx| {
                            menu.update(cx, |menu, cx| {
                                if *hovered && menu.highlighted != Some(index) {
                                    menu.highlighted = Some(index);
                                    cx.notify();
                                }
                            });
                        })
                        .on_click(move |_event, _window, cx| choose(index, cx))
                };

                div().px(px(4.)).child(row)
            })
            .collect::<Vec<_>>();

        let panel = div()
            .id(format!("{}-context-menu-panel", node.id))
            .role(Role::Menu)
            .track_focus(&focus)
            .occlude()
            .flex()
            .flex_col()
            .min_w(px(180.))
            .py(px(4.))
            .bg(theme.popover)
            .text_color(theme.popover_foreground)
            .text_size(px(13.))
            .line_height(px(20.))
            .border_1()
            .border_color(theme.border)
            .rounded(px(8.))
            .shadow(vec![
                BoxShadow {
                    color: hsla(0., 0., 0., 0.12),
                    offset: point(px(0.), px(2.)),
                    blur_radius: px(3.),
                    spread_radius: px(0.),
                    inset: false,
                },
                BoxShadow {
                    color: hsla(0., 0., 0., 0.04),
                    offset: point(px(0.), px(1.)),
                    blur_radius: px(0.),
                    spread_radius: px(0.),
                    inset: false,
                },
            ])
            .on_mouse_down_out({
                let menu = menu.clone();
                move |_event, _window, cx| menu.update(cx, |menu, cx| menu.close(cx))
            })
            .on_key_down({
                let menu = menu.clone();
                move |event, _window, cx| {
                    let key = event.keystroke.key.as_str();
                    let highlighted = menu.read(cx).highlighted;
                    match key {
                        "escape" => menu.update(cx, |menu, cx| menu.close(cx)),
                        "enter" | "space" => {
                            if let Some(index) = highlighted {
                                choose(index, cx);
                            }
                        }
                        "up" | "down" => {
                            let next = step(&enabled, highlighted, key == "down");
                            menu.update(cx, |menu, cx| {
                                menu.highlighted = next;
                                cx.notify();
                            });
                        }
                        _ => return,
                    }
                    cx.stop_propagation();
                }
            })
            .children(rows);

        element = element.child(
            deferred(
                anchored()
                    .position(position)
                    .snap_to_window_with_margin(px(8.))
                    .child(panel),
            )
            .with_priority(1),
        );
    }

    element.into_any_element()
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct MenuState {
    position: Option<gpui::Point<gpui::Pixels>>,
    highlighted: Option<usize>,
    focus: gpui::FocusHandle,
}

#[cfg(feature = "components")]
impl MenuState {
    fn close(&mut self, cx: &mut gpui::Context<Self>) {
        if self.position.take().is_some() {
            self.highlighted = None;
            cx.notify();
        }
    }
}

/// The next enabled item from `current`, wrapping around; the first (or last)
/// enabled item when nothing is highlighted yet.
#[cfg(feature = "components")]
fn step(enabled: &[bool], current: Option<usize>, forward: bool) -> Option<usize> {
    let count = enabled.len();
    let start = match (current, forward) {
        (Some(index), true) => index + 1,
        (Some(index), false) => index + count - 1,
        (None, true) => 0,
        (None, false) => count.checked_sub(1)?,
    };
    (0..count)
        .map(|offset| {
            if forward {
                (start + offset) % count
            } else {
                (start + count - offset) % count
            }
        })
        .find(|&index| enabled[index])
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: ContextMenuComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    super::render_component_fallback(node.style, None, node.children, context)
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use crate::gpui;
    use gpui::{point, px, size, IntoElement, Modifiers, MouseButton, VisualTestContext};

    fn row_with_menu() -> crate::ElementNode {
        let item = |value: &str, disabled| {
            crate::ElementNode::DropdownMenuItemComponent(crate::DropdownMenuItemComponentNode {
                style: crate::StyleAttrs::default(),
                value: value.to_string(),
                label: value.to_string(),
                disabled,
                checked: false,
            })
        };
        let mut style = crate::StyleAttrs::default();
        style.width = Some(px(200.0).into());
        style.height = Some(px(40.0).into());
        crate::ElementNode::ContextMenuComponent(crate::ContextMenuComponentNode {
            style,
            id: "row".to_string(),
            children: vec![item("move", false), item("off", true), item("pin", false)],
            select: Some("picked".to_string()),
        })
    }

    fn open(cx: &mut gpui::TestAppContext) -> (crate::SharedRuntime, &mut VisualTestContext) {
        cx.update(gpui_component::init);
        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(row_with_menu(), Vec::new()));
        let runtime_for_view = runtime.clone();
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state, runtime_for_view, 7, false, false)
        });
        cx.draw(
            point(px(0.0), px(0.0)),
            size(px(400.0), px(300.0)),
            |_window, _cx| view.clone().into_any_element(),
        );
        let at = point(px(20.0), px(20.0));
        cx.simulate_mouse_down(at, MouseButton::Right, Modifiers::default());
        cx.simulate_mouse_up(at, MouseButton::Right, Modifiers::default());
        redraw(cx);
        (runtime, cx)
    }

    fn redraw(cx: &mut VisualTestContext) {
        cx.update(|window, cx| window.draw(cx).clear(cx));
    }

    // Rows start below the panel's border and padding, 22 pixels apart.
    fn item(index: usize) -> gpui::Point<gpui::Pixels> {
        point(px(60.0), px(20.0 + 5.0 + 11.0 + 22.0 * index as f32))
    }

    fn picked(runtime: &crate::SharedRuntime) -> Vec<String> {
        runtime
            .events
            .lock()
            .unwrap()
            .iter()
            .filter_map(|event| match event {
                crate::NativeEvent::Input {
                    event,
                    value: Some(crate::EventValue::String(value)),
                    ..
                } if event == "picked" => Some(value.clone()),
                _ => None,
            })
            .collect()
    }

    #[gpui::test]
    fn right_click_opens_the_menu_at_the_pointer_and_a_click_chooses(
        cx: &mut gpui::TestAppContext,
    ) {
        let (runtime, cx) = open(cx);
        cx.simulate_click(item(2), Modifiers::default());
        assert_eq!(picked(&runtime), vec!["pin"]);

        // Choosing closed the menu.
        redraw(cx);
        cx.simulate_click(item(0), Modifiers::default());
        assert_eq!(picked(&runtime), vec!["pin"]);
    }

    #[gpui::test]
    fn disabled_items_ignore_clicks_and_arrow_keys(cx: &mut gpui::TestAppContext) {
        let (runtime, cx) = open(cx);
        cx.simulate_click(item(1), Modifiers::default());
        assert!(picked(&runtime).is_empty());

        cx.simulate_keystrokes("down down enter");
        assert_eq!(picked(&runtime), vec!["pin"]);
    }

    #[gpui::test]
    fn escape_closes_without_choosing(cx: &mut gpui::TestAppContext) {
        let (runtime, cx) = open(cx);
        cx.simulate_keystrokes("down escape");
        redraw(cx);
        cx.simulate_click(item(0), Modifiers::default());
        assert!(picked(&runtime).is_empty());
    }

    #[test]
    fn steps_wrap_and_skip_disabled_items() {
        let enabled = [true, false, true];
        assert_eq!(super::step(&enabled, None, true), Some(0));
        assert_eq!(super::step(&enabled, None, false), Some(2));
        assert_eq!(super::step(&enabled, Some(0), true), Some(2));
        assert_eq!(super::step(&enabled, Some(2), true), Some(0));
        assert_eq!(super::step(&enabled, Some(0), false), Some(2));
        assert_eq!(super::step(&[false], None, true), None);
        assert_eq!(super::step(&[], None, true), None);
    }
}
