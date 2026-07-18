use crate::element::ElementRenderContext;
use crate::{gpui, TreeComponentNode, TreeItemComponentNode};

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
pub(crate) type ComponentTree = super::virtual_list::ComponentVirtualList;

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct TreeItem {
    id: String,
    parent_id: Option<String>,
    level: usize,
    branch: bool,
    expanded: bool,
    position: Option<usize>,
    set_size: Option<usize>,
    disabled: bool,
    style: crate::StyleAttrs,
    children: Vec<ElementNode>,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct VisibleTree {
    id: String,
    items: Arc<Vec<TreeItem>>,
    offset: usize,
    total_count: usize,
    overscan: usize,
    selected: Option<String>,
    change_event: String,
    toggle_event: String,
    range_event: Option<String>,
    item_height: f32,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct TreeKey {
    id: String,
    parent_id: Option<String>,
    level: usize,
    branch: bool,
    expanded: bool,
    disabled: bool,
    index: usize,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: TreeComponentNode,
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
            ElementNode::TreeItemComponent(item) => Some(TreeItem {
                id: item.id,
                parent_id: item.parent_id,
                level: usize::try_from(item.level).unwrap_or(usize::MAX).max(1),
                branch: item.branch,
                expanded: item.expanded,
                position: item.position.and_then(|value| usize::try_from(value).ok()),
                set_size: item.set_size.and_then(|value| usize::try_from(value).ok()),
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
    let keys = items
        .iter()
        .enumerate()
        .map(|(local_index, item)| TreeKey {
            id: item.id.clone(),
            parent_id: item.parent_id.clone(),
            level: item.level,
            branch: item.branch,
            expanded: item.expanded,
            disabled: item.disabled,
            index: offset.saturating_add(local_index),
        })
        .collect::<Vec<_>>();
    let selected_index = node
        .selected_index
        .and_then(|index| usize::try_from(index).ok())
        .filter(|index| *index < total_count)
        .or_else(|| {
            node.selected.as_ref().and_then(|selected| {
                keys.iter()
                    .find(|key| key.id == *selected)
                    .map(|key| key.index)
            })
        });

    if context.components.tree_mut(&node.id).is_none() {
        let component = ComponentTree::new(context.cx);
        context.components.insert_tree(&node.id, component);
    }

    let component = context
        .components
        .tree_mut(&node.id)
        .expect("tree component must exist after insertion");
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
                keys.iter()
                    .find(|key| key.id == *reveal)
                    .map(|key| (reveal.clone(), key.index))
            })
        });
    if component.last_reveal != reveal {
        component.last_reveal = reveal.clone();
        if let Some((_id, index)) = reveal {
            component.scroll_handle.scroll_to_item(
                index,
                super::virtual_list::scroll_strategy(node.reveal_strategy.as_deref()),
            );
        }
    }
    if node.range.is_none() {
        component.last_requested_range = None;
    }
    let scroll_handle = component.scroll_handle.clone();
    let focus_handle = component.focus_handle.clone();

    let visible_tree = VisibleTree {
        id: node.id.clone(),
        items: items.clone(),
        offset,
        total_count,
        overscan,
        selected: node.selected.clone(),
        change_event: node.change.clone().unwrap_or_default(),
        toggle_event: node.toggle.clone().unwrap_or_default(),
        range_event: node.range.clone(),
        item_height: (node.item_height as f32).max(1.0),
    };
    let processor = context.cx.processor(move |root, range, window, cx| {
        render_visible(root, &visible_tree, range, window, cx)
    });

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.unwrap_or_default();
    let toggle_event = node.toggle.unwrap_or_default();
    let key_items = keys.clone();
    let key_scroll = scroll_handle.clone();
    let disabled = node.disabled;
    let selected_for_keys = selected_index
        .and_then(|selected_index| keys.iter().position(|key| key.index == selected_index));

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id.clone())
        .role(Role::Tree)
        .aria_label(node.label.unwrap_or_else(|| "Tree".to_string()))
        .track_focus(&focus_handle.tab_stop(!disabled))
        .on_key_down(move |event, window, cx| {
            if disabled {
                return;
            }
            let Some(action) = key_action(
                event.keystroke.key.as_str(),
                &key_items,
                selected_for_keys,
                total_count,
            ) else {
                return;
            };
            match action {
                TreeAction::Select(position) => {
                    let item = &key_items[position];
                    super::virtual_list::emit_change(
                        &runtime,
                        window_id,
                        Some(&change_event),
                        &item.id,
                    );
                    key_scroll.scroll_to_item(item.index, gpui::ScrollStrategy::Nearest);
                }
                TreeAction::Toggle(position) => {
                    super::virtual_list::emit_change(
                        &runtime,
                        window_id,
                        Some(&toggle_event),
                        &key_items[position].id,
                    );
                }
            }
            window.refresh();
            cx.stop_propagation();
        })
        .child(
            uniform_list(
                format!("gpui-elixir-tree-{window_id}-{}", node.id),
                total_count,
                processor,
            )
            .track_scroll(&scroll_handle)
            .size_full(),
        )
        .into_any_element()
}

#[cfg(feature = "components")]
fn render_visible(
    root: &mut crate::ElixirRoot,
    tree: &VisibleTree,
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
    let tree_id = tree.id.as_str();
    let Some(component) = root.components.tree_mut(tree_id) else {
        return Vec::new();
    };
    let requested_range = range.start.saturating_sub(tree.overscan)
        ..range
            .end
            .saturating_add(tree.overscan)
            .min(tree.total_count);
    super::virtual_list::schedule_range(
        component,
        super::virtual_list::VirtualCollectionKind::Tree,
        &tree.id,
        requested_range,
        tree.range_event.as_deref(),
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
            .checked_sub(tree.offset)
            .and_then(|local_index| tree.items.get(local_index))
            .cloned();
        let Some(item) = item else {
            rendered.push(gpui::div().h(gpui::px(tree.item_height)).into_any_element());
            continue;
        };
        let item_id = item.id.clone();
        let selected = tree.selected.as_deref() == Some(item.id.as_str());
        let item_runtime = runtime.clone();
        let item_focus = component.focus_handle.clone();
        let select_event = tree.change_event.clone();
        let toggle_event = tree.toggle_event.clone();
        let event_id = item.id.clone();
        let branch = item.branch;
        let item_element_id = format!("gpui-elixir-tree-item-{window_id}-{tree_id}-{item_id}");
        let children = {
            let mut item_context = ElementRenderContext {
                runtime: runtime.clone(),
                window_id,
                next_element_id: 0,
                id_namespace: format!("tree-{tree_id}-{item_id}"),
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
            .h(gpui::px(tree.item_height))
            .id(item_element_id)
            .role(Role::TreeItem)
            .aria_level(item.level)
            .aria_selected(selected)
            .children(children);
        if let Some(position) = item.position {
            element = element.aria_position_in_set(position);
        }
        if let Some(set_size) = item.set_size {
            element = element.aria_size_of_set(set_size);
        }
        if item.branch {
            element = element.aria_expanded(item.expanded);
        }
        if selected {
            element = element.aria_active_descendant();
        }
        if !item.disabled {
            element = element.cursor(gpui::CursorStyle::PointingHand).on_click(
                move |event, window, cx| {
                    item_focus.focus(window, cx);
                    if branch && event.click_count() == 2 {
                        super::virtual_list::emit_change(
                            &item_runtime,
                            window_id,
                            Some(&toggle_event),
                            &event_id,
                        );
                    } else {
                        super::virtual_list::emit_change(
                            &item_runtime,
                            window_id,
                            Some(&select_event),
                            &event_id,
                        );
                    }
                },
            );
        }
        rendered.push(element.into_any_element());
    }

    component
        .input_entities
        .retain(|input_id, _entity| active_input_ids.contains(input_id));
    component.components.finish_render(window, cx);

    let input_prefix = format!("gpui-elixir-input-{window_id}-tree-{tree_id}-");
    if let Ok(mut input_values) = runtime.input_values.lock() {
        input_values.retain(|input_id, _value| {
            !input_id.starts_with(&input_prefix) || active_input_ids.contains(input_id)
        });
    }
    rendered
}

#[cfg(feature = "components")]
#[derive(Clone, Copy)]
enum TreeAction {
    Select(usize),
    Toggle(usize),
}

#[cfg(feature = "components")]
fn key_action(
    key: &str,
    items: &[TreeKey],
    selected: Option<usize>,
    total_count: usize,
) -> Option<TreeAction> {
    match key {
        "down" => next_enabled(items, selected).map(TreeAction::Select),
        "up" => previous_enabled(items, selected).map(TreeAction::Select),
        "home" => items
            .iter()
            .position(|item| item.index == 0 && !item.disabled)
            .map(TreeAction::Select),
        "end" => items
            .iter()
            .rposition(|item| item.index.saturating_add(1) == total_count && !item.disabled)
            .map(TreeAction::Select),
        "left" => left_action(items, selected),
        "right" => right_action(items, selected),
        "enter" | "space" => selected
            .filter(|position| !items[*position].disabled)
            .map(TreeAction::Select),
        _other => None,
    }
}

#[cfg(feature = "components")]
fn left_action(items: &[TreeKey], selected: Option<usize>) -> Option<TreeAction> {
    let selected = selected?;
    let item = &items[selected];
    if item.disabled {
        return None;
    }
    if item.branch && item.expanded {
        return Some(TreeAction::Toggle(selected));
    }
    let parent = item.parent_id.as_ref()?;
    items
        .iter()
        .position(|candidate| candidate.id == *parent && !candidate.disabled)
        .map(TreeAction::Select)
}

#[cfg(feature = "components")]
fn right_action(items: &[TreeKey], selected: Option<usize>) -> Option<TreeAction> {
    let selected = selected?;
    let item = &items[selected];
    if item.disabled || !item.branch {
        return None;
    }
    if !item.expanded {
        return Some(TreeAction::Toggle(selected));
    }
    items
        .iter()
        .enumerate()
        .skip(selected + 1)
        .find(|(_position, candidate)| {
            candidate.level == item.level.saturating_add(1)
                && candidate.parent_id.as_deref() == Some(item.id.as_str())
                && !candidate.disabled
        })
        .map(|(position, _candidate)| TreeAction::Select(position))
}

#[cfg(feature = "components")]
fn next_enabled(items: &[TreeKey], selected: Option<usize>) -> Option<usize> {
    let start = selected.map_or(0, |index| index.saturating_add(1));
    (start..items.len()).find(|index| !items[*index].disabled)
}

#[cfg(feature = "components")]
fn previous_enabled(items: &[TreeKey], selected: Option<usize>) -> Option<usize> {
    let end = selected.unwrap_or(items.len());
    (0..end).rev().find(|index| !items[*index].disabled)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: TreeComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(feature = "components")]
pub(crate) fn render_item(
    node: TreeItemComponentNode,
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
    node: TreeItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, None, node.children, context)
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::*;

    fn key(
        id: &str,
        parent_id: Option<&str>,
        level: usize,
        branch: bool,
        expanded: bool,
        disabled: bool,
        index: usize,
    ) -> TreeKey {
        TreeKey {
            id: id.to_string(),
            parent_id: parent_id.map(str::to_string),
            level,
            branch,
            expanded,
            disabled,
            index,
        }
    }

    #[test]
    fn tree_keys_expand_and_navigate_hierarchy_while_skipping_disabled_items() {
        let collapsed = vec![
            key("root", None, 1, true, false, false, 0),
            key("disabled", Some("root"), 2, false, false, true, 1),
            key("child", Some("root"), 2, false, false, false, 2),
        ];
        assert!(matches!(
            key_action("right", &collapsed, Some(0), collapsed.len()),
            Some(TreeAction::Toggle(0))
        ));
        assert!(matches!(
            key_action("down", &collapsed, Some(0), collapsed.len()),
            Some(TreeAction::Select(2))
        ));

        let mut expanded = collapsed;
        expanded[0].expanded = true;
        assert!(matches!(
            key_action("right", &expanded, Some(0), expanded.len()),
            Some(TreeAction::Select(2))
        ));
        assert!(matches!(
            key_action("left", &expanded, Some(2), expanded.len()),
            Some(TreeAction::Select(0))
        ));
        assert!(matches!(
            key_action("left", &expanded, Some(0), expanded.len()),
            Some(TreeAction::Toggle(0))
        ));
    }
}
