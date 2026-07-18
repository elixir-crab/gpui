use crate::element::ElementRenderContext;
use crate::{gpui, VirtualListComponentNode, VirtualListItemComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;
#[cfg(feature = "components")]
use crate::element::ElementNode;

#[cfg(feature = "components")]
use std::collections::HashSet;
#[cfg(feature = "components")]
use std::ops::Range;
#[cfg(feature = "components")]
use std::sync::Arc;

#[cfg(feature = "components")]
pub(crate) type ComponentVirtualList = super::uniform_collection::ComponentUniformCollection;

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
    let selected_index = super::uniform_collection::controlled_index(
        total_count,
        node.selected_index,
        node.selected.as_deref(),
        |selected| {
            item_keys
                .iter()
                .find(|(id, _disabled, _index)| id == selected)
                .map(|(_id, _disabled, index)| *index)
        },
    );

    if context.components.virtual_list_mut(&node.id).is_none() {
        let component = ComponentVirtualList::new(context.cx);
        context.components.insert_virtual_list(&node.id, component);
    }

    let component = context
        .components
        .virtual_list_mut(&node.id)
        .expect("virtual list component must exist after insertion");
    let reveal = super::uniform_collection::controlled_reveal(
        total_count,
        node.reveal_index,
        node.reveal.as_deref(),
        |reveal| {
            item_keys
                .iter()
                .find(|(id, _disabled, _index)| id == reveal)
                .map(|(_id, _disabled, index)| *index)
        },
    );
    component.reconcile_reveal(reveal, node.reveal_strategy.as_deref());
    component.reset_range_without_event(node.range.as_deref());
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
            super::uniform_collection::emit_change(
                &runtime,
                window_id,
                change_event.as_deref(),
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
    super::uniform_collection::schedule_range(
        component,
        super::uniform_collection::CollectionKind::List,
        &list.id,
        requested_range,
        list.range_event.as_deref(),
        &runtime,
        window_id,
        window,
        cx,
    );

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
                    super::uniform_collection::emit_change(
                        &item_runtime,
                        window_id,
                        event_name.as_deref(),
                        &event_id,
                    );
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
fn key_target(
    key: &str,
    items: &[(String, bool, usize)],
    selected: Option<usize>,
    total_count: usize,
) -> Option<usize> {
    super::uniform_collection::linear_key_target(
        key,
        items,
        selected,
        total_count,
        |item| item.2,
        |item| item.1,
    )
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
