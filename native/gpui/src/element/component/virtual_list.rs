use crate::element::ElementRenderContext;
use crate::{gpui, VirtualListComponentNode, VirtualListItemComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;
#[cfg(feature = "components")]
use crate::element::{component_registry::ComponentRegistry, ElementNode};
#[cfg(feature = "components")]
use crate::NativeTextInput;

#[cfg(feature = "components")]
use std::collections::{HashMap, HashSet};
#[cfg(feature = "components")]
use std::ops::Range;
#[cfg(feature = "components")]
use std::sync::Arc;

#[cfg(feature = "components")]
pub(crate) struct ComponentVirtualList {
    scroll_handle: gpui::UniformListScrollHandle,
    focus_handle: gpui::FocusHandle,
    last_reveal: Option<(String, usize)>,
    last_requested_range: Option<Range<usize>>,
    pending_requested_range: Option<Range<usize>>,
    range_emit_scheduled: bool,
    input_entities: HashMap<String, gpui::Entity<NativeTextInput>>,
    components: ComponentRegistry,
}

#[cfg(feature = "components")]
impl ComponentVirtualList {
    pub(crate) fn new(cx: &mut gpui::Context<'_, crate::ElixirRoot>) -> Self {
        Self {
            scroll_handle: gpui::UniformListScrollHandle::new(),
            focus_handle: cx.focus_handle(),
            last_reveal: None,
            last_requested_range: None,
            pending_requested_range: None,
            range_emit_scheduled: false,
            input_entities: HashMap::new(),
            components: ComponentRegistry::default(),
        }
    }
}

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct VirtualItem {
    id: String,
    disabled: bool,
    style: crate::StyleAttrs,
    children: Vec<ElementNode>,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct VisibleList {
    id: String,
    items: Arc<Vec<VirtualItem>>,
    offset: usize,
    total_count: usize,
    overscan: usize,
    selected: Option<String>,
    change_event: Option<String>,
    range_event: Option<String>,
    item_height: f32,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: VirtualListComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        uniform_list, InteractiveElement, IntoElement, ParentElement, Role,
        StatefulInteractiveElement, Styled,
    };

    let items = node
        .children
        .into_iter()
        .filter_map(|child| match child {
            ElementNode::VirtualListItemComponent(item) => Some(VirtualItem {
                id: item.id,
                disabled: item.disabled,
                style: item.style,
                children: item.children,
            }),
            _other => None,
        })
        .collect::<Vec<_>>();
    let items = Arc::new(items);
    let total_count = usize::try_from(node.total_count).unwrap_or(usize::MAX);
    let offset = usize::try_from(node.offset)
        .unwrap_or(usize::MAX)
        .min(total_count);
    let overscan = usize::try_from(node.overscan).unwrap_or(usize::MAX);
    let item_keys = items
        .iter()
        .enumerate()
        .map(|(local_index, item)| {
            (
                item.id.clone(),
                item.disabled,
                offset.saturating_add(local_index),
            )
        })
        .collect::<Vec<_>>();
    let selected_index = node
        .selected_index
        .and_then(|index| usize::try_from(index).ok())
        .filter(|index| *index < total_count)
        .or_else(|| {
            node.selected.as_ref().and_then(|selected| {
                item_keys
                    .iter()
                    .find(|(id, _disabled, _index)| id == selected)
                    .map(|(_id, _disabled, index)| *index)
            })
        });

    if context.components.virtual_list_mut(&node.id).is_none() {
        let component = ComponentVirtualList::new(context.cx);
        context.components.insert_virtual_list(&node.id, component);
    }

    let component = context
        .components
        .virtual_list_mut(&node.id)
        .expect("virtual list component must exist after insertion");
    let reveal = node
        .reveal_index
        .and_then(|index| usize::try_from(index).ok())
        .filter(|index| *index < total_count)
        .map(|index| {
            (
                node.reveal
                    .clone()
                    .unwrap_or_else(|| format!("index-{index}")),
                index,
            )
        })
        .or_else(|| {
            node.reveal.as_ref().and_then(|reveal| {
                item_keys
                    .iter()
                    .find(|(id, _disabled, _index)| id == reveal)
                    .map(|(_id, _disabled, index)| (reveal.clone(), *index))
            })
        });
    if component.last_reveal != reveal {
        component.last_reveal = reveal.clone();
        if let Some((_id, index)) = reveal {
            component
                .scroll_handle
                .scroll_to_item(index, scroll_strategy(node.reveal_strategy.as_deref()));
        }
    }
    if node.range.is_none() {
        component.last_requested_range = None;
    }
    let scroll_handle = component.scroll_handle.clone();
    let focus_handle = component.focus_handle.clone();

    let visible_list = VisibleList {
        id: node.id.clone(),
        items: items.clone(),
        offset,
        total_count,
        overscan,
        selected: node.selected.clone(),
        change_event: node.change.clone(),
        range_event: node.range.clone(),
        item_height: (node.item_height as f32).max(1.0),
    };
    let processor = context.cx.processor(move |root, range, window, cx| {
        render_visible_items(root, &visible_list, range, window, cx)
    });

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let key_items = item_keys.clone();
    let key_scroll = scroll_handle.clone();
    let disabled = node.disabled;
    let selected_for_keys = selected_index.and_then(|selected_index| {
        item_keys
            .iter()
            .position(|(_id, _disabled, index)| *index == selected_index)
    });

    let element = apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id.clone())
        .role(Role::ListBox)
        .aria_label(node.label.unwrap_or_else(|| "Items".to_string()))
        .track_focus(&focus_handle.tab_stop(!disabled))
        .on_key_down(move |event, window, cx| {
            if disabled {
                return;
            }
            let target = key_target(
                event.keystroke.key.as_str(),
                &key_items,
                selected_for_keys,
                total_count,
            );
            let Some(target) = target else {
                return;
            };
            emit_change(
                &runtime,
                window_id,
                change_event.as_ref(),
                &key_items[target].0,
            );
            key_scroll.scroll_to_item(key_items[target].2, gpui::ScrollStrategy::Nearest);
            window.refresh();
            cx.stop_propagation();
        })
        .child(
            uniform_list(
                format!("gpui-elixir-virtual-list-{window_id}-{}", node.id),
                total_count,
                processor,
            )
            .track_scroll(&scroll_handle)
            .size_full(),
        );

    element.into_any_element()
}

#[cfg(feature = "components")]
fn render_visible_items(
    root: &mut crate::ElixirRoot,
    list: &VisibleList,
    range: Range<usize>,
    window: &mut gpui::Window,
    cx: &mut gpui::Context<'_, crate::ElixirRoot>,
) -> Vec<gpui::AnyElement> {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };

    let runtime = root.runtime.clone();
    let window_id = root.window_id;
    let list_id = list.id.as_str();
    let Some(component) = root.components.virtual_list_mut(list_id) else {
        return Vec::new();
    };
    let requested_range = range.start.saturating_sub(list.overscan)
        ..range
            .end
            .saturating_add(list.overscan)
            .min(list.total_count);
    let schedule_range = if list.range_event.is_some() {
        component.pending_requested_range = Some(requested_range);
        if component.range_emit_scheduled {
            false
        } else {
            component.range_emit_scheduled = true;
            true
        }
    } else {
        false
    };
    if schedule_range {
        let list_id = list.id.clone();
        let event = list
            .range_event
            .clone()
            .expect("scheduled virtual range must have an event");
        cx.defer_in(window, move |root, _window, _cx| {
            let runtime = root.runtime.clone();
            let window_id = root.window_id;
            let Some(component) = root.components.virtual_list_mut(&list_id) else {
                return;
            };
            component.range_emit_scheduled = false;
            let Some(requested_range) = component.pending_requested_range.take() else {
                return;
            };
            if component.last_requested_range.as_ref() == Some(&requested_range) {
                return;
            }
            component.last_requested_range = Some(requested_range.clone());
            emit_range(
                &runtime,
                window_id,
                &event,
                requested_range.start,
                requested_range.end,
            );
        });
    }

    component.components.begin_render();
    let mut active_input_ids = HashSet::new();
    let mut rendered = Vec::new();

    for index in range {
        let item = index
            .checked_sub(list.offset)
            .and_then(|local_index| list.items.get(local_index))
            .cloned();
        let Some(item) = item else {
            rendered.push(gpui::div().h(gpui::px(list.item_height)).into_any_element());
            continue;
        };
        let item_id = item.id.clone();
        let item_selected = list.selected.as_deref() == Some(item.id.as_str());
        let item_disabled = item.disabled;
        let item_runtime = runtime.clone();
        let item_focus = component.focus_handle.clone();
        let event_id = item.id.clone();
        let event_name = list.change_event.clone();
        let item_element_id = format!("gpui-elixir-virtual-item-{window_id}-{list_id}-{item_id}");
        let children = {
            let mut item_context = ElementRenderContext {
                runtime: runtime.clone(),
                window_id,
                next_element_id: 0,
                id_namespace: format!("virtual-{list_id}-{item_id}"),
                active_input_ids: &mut active_input_ids,
                input_entities: &mut component.input_entities,
                components: &mut component.components,
                window,
                cx,
            };
            item.children
                .into_iter()
                .map(|child| child.render(&mut item_context))
                .collect::<Vec<_>>()
        };
        let mut element = apply_generated_render_styles(gpui::div(), item.style)
            .h(gpui::px(list.item_height))
            .id(item_element_id)
            .role(Role::ListBoxOption)
            .children(children);
        if item_selected {
            element = element.aria_active_descendant();
        }
        if !item_disabled {
            element = element.cursor(gpui::CursorStyle::PointingHand).on_click(
                move |_event, window, cx| {
                    item_focus.focus(window, cx);
                    emit_change(&item_runtime, window_id, event_name.as_ref(), &event_id);
                },
            );
        }
        rendered.push(element.into_any_element());
    }

    component
        .input_entities
        .retain(|input_id, _entity| active_input_ids.contains(input_id));
    component.components.finish_render(window, cx);

    let input_prefix = format!("gpui-elixir-input-{window_id}-virtual-{list_id}-");
    if let Ok(mut input_values) = runtime.input_values.lock() {
        input_values.retain(|input_id, _value| {
            !input_id.starts_with(&input_prefix) || active_input_ids.contains(input_id)
        });
    }
    rendered
}

#[cfg(feature = "components")]
fn emit_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&String>,
    value: &str,
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
            value: Some(EventValue::String(value.to_string())),
        },
    );
}

#[cfg(feature = "components")]
fn emit_range(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: &str,
    first: usize,
    last: usize,
) {
    use crate::{push_event, NativeEvent};

    let _ = push_event(
        runtime,
        NativeEvent::VirtualRange {
            window_id,
            event: event.to_string(),
            first: first as u64,
            last: last as u64,
        },
    );
}

#[cfg(feature = "components")]
fn key_target(
    key: &str,
    items: &[(String, bool, usize)],
    selected: Option<usize>,
    total_count: usize,
) -> Option<usize> {
    match key {
        "down" => next_enabled(items, selected),
        "up" => previous_enabled(items, selected),
        "home" => items
            .iter()
            .position(|(_id, disabled, index)| *index == 0 && !disabled),
        "end" => items.iter().rposition(|(_id, disabled, index)| {
            index.saturating_add(1) == total_count && !disabled
        }),
        "enter" | "space" => selected.filter(|index| !items[*index].1),
        _other => None,
    }
}

#[cfg(feature = "components")]
fn next_enabled(items: &[(String, bool, usize)], selected: Option<usize>) -> Option<usize> {
    let start = selected.map_or(0, |index| index.saturating_add(1));
    (start..items.len()).find(|index| !items[*index].1)
}

#[cfg(feature = "components")]
fn previous_enabled(items: &[(String, bool, usize)], selected: Option<usize>) -> Option<usize> {
    let end = selected.unwrap_or(items.len());
    (0..end).rev().find(|index| !items[*index].1)
}

#[cfg(feature = "components")]
fn scroll_strategy(strategy: Option<&str>) -> gpui::ScrollStrategy {
    match strategy {
        Some("top") => gpui::ScrollStrategy::Top,
        Some("center") => gpui::ScrollStrategy::Center,
        Some("bottom") => gpui::ScrollStrategy::Bottom,
        _other => gpui::ScrollStrategy::Nearest,
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: VirtualListComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(feature = "components")]
pub(crate) fn render_item(
    node: VirtualListItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{IntoElement, ParentElement};

    let children = node
        .children
        .into_iter()
        .map(|child| child.render(context))
        .collect::<Vec<_>>();
    apply_generated_render_styles(gpui::div(), node.style)
        .children(children)
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_item(
    node: VirtualListItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, None, node.children, context)
}
