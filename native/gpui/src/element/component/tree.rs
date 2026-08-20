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
pub(crate) type ComponentTree = super::uniform_collection::ComponentUniformCollection;

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
        prelude::FluentBuilder, uniform_list, InteractiveElement, IntoElement, ParentElement, Role,
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
    let selected_index = super::uniform_collection::controlled_index(
        total_count,
        node.selected_index,
        node.selected.as_deref(),
        |selected| {
            keys.iter()
                .find(|key| key.id == selected)
                .map(|key| key.index)
        },
    );

    if context.components.tree_mut(&node.id).is_none() {
        let component = ComponentTree::new(context.cx);
        context.components.insert_tree(&node.id, component);
    }

    let component = context
        .components
        .tree_mut(&node.id)
        .expect("tree component must exist after insertion");
    let reveal = super::uniform_collection::controlled_reveal(
        total_count,
        node.reveal_index,
        node.reveal.as_deref(),
        |reveal| {
            keys.iter()
                .find(|key| key.id == reveal)
                .map(|key| key.index)
        },
    );
    component.reconcile_reveal(reveal, node.reveal_strategy.as_deref());
    component.reset_range_without_event(node.range.as_deref());
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
    let group_focus = focus_handle.clone();
    let selected_for_keys = selected_index
        .and_then(|selected_index| keys.iter().position(|key| key.index == selected_index));

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id.clone())
        .debug_selector(|| node.id.clone())
        .role(Role::Tree)
        .aria_label(node.label.unwrap_or_else(|| "Tree".to_string()))
        .track_focus(&focus_handle.tab_stop(!disabled))
        .when(!disabled, |element| {
            element.on_click(move |_event, window, cx| group_focus.focus(window, cx))
        })
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
                    super::uniform_collection::emit_change(
                        &runtime,
                        window_id,
                        Some(change_event.as_str()),
                        &item.id,
                    );
                    key_scroll.scroll_to_item(item.index, gpui::ScrollStrategy::Nearest);
                }
                TreeAction::Toggle(position) => {
                    super::uniform_collection::emit_change(
                        &runtime,
                        window_id,
                        Some(toggle_event.as_str()),
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
    super::uniform_collection::schedule_range(
        component,
        super::uniform_collection::CollectionKind::Tree,
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
                        super::uniform_collection::emit_change(
                            &item_runtime,
                            window_id,
                            Some(toggle_event.as_str()),
                            &event_id,
                        );
                    } else {
                        super::uniform_collection::emit_change(
                            &item_runtime,
                            window_id,
                            Some(select_event.as_str()),
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
        "left" => left_action(items, selected),
        "right" => right_action(items, selected),
        _other => super::uniform_collection::linear_key_target(
            key,
            items,
            selected,
            total_count,
            |item| item.index,
            |item| item.disabled,
        )
        .map(TreeAction::Select),
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

    fn tree(selected: &str, expanded: bool, disabled: bool) -> crate::ElementNode {
        crate::ElementNode::TreeComponent(crate::TreeComponentNode {
            style: crate::StyleAttrs::default(),
            id: "files".to_string(),
            label: Some("Files".to_string()),
            selected: Some(selected.to_string()),
            selected_index: None,
            reveal: None,
            reveal_index: None,
            reveal_strategy: Some("nearest".to_string()),
            total_count: 4,
            offset: 0,
            overscan: 2,
            item_height: 40.0,
            disabled,
            children: vec![
                item("root", None, 1, true, expanded, false),
                item("disabled", Some("root"), 2, false, false, true),
                item("child", Some("root"), 2, false, false, false),
                item("sibling", None, 1, false, false, false),
            ],
            change: Some("tree_selected".to_string()),
            toggle: Some("tree_toggled".to_string()),
            range: None,
        })
    }

    fn item(
        id: &str,
        parent_id: Option<&str>,
        level: u64,
        branch: bool,
        expanded: bool,
        disabled: bool,
    ) -> crate::ElementNode {
        crate::ElementNode::TreeItemComponent(crate::TreeItemComponentNode {
            style: crate::StyleAttrs::default(),
            id: id.to_string(),
            parent_id: parent_id.map(str::to_string),
            level,
            branch,
            expanded,
            position: None,
            set_size: None,
            disabled,
            children: Vec::new(),
        })
    }

    #[gpui::test]
    fn rendered_tree_keyboard_navigation_selects_and_toggles_hierarchy(
        cx: &mut gpui::TestAppContext,
    ) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            tree("root", false, false),
            gpui::size(gpui::px(320.0), gpui::px(200.0)),
        );

        harness.focus_component("tree", "files");
        harness.simulate_keystrokes("right");
        assert_change(harness.take_events(), "tree_toggled", "root");

        harness.simulate_keystrokes("down");
        assert_change(harness.take_events(), "tree_selected", "child");
    }

    #[gpui::test]
    fn rendered_expanded_tree_navigates_to_children(cx: &mut gpui::TestAppContext) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            tree("root", true, false),
            gpui::size(gpui::px(320.0), gpui::px(200.0)),
        );

        harness.focus_component("tree", "files");
        harness.simulate_keystrokes("right");
        assert_change(harness.take_events(), "tree_selected", "child");
    }

    #[gpui::test]
    fn disabled_tree_blocks_keyboard_events(cx: &mut gpui::TestAppContext) {
        let mut harness = crate::test_harness::NativeTestHarness::new(
            cx,
            tree("root", false, true),
            gpui::size(gpui::px(320.0), gpui::px(200.0)),
        );

        harness.focus_component("tree", "files");
        harness.simulate_keystrokes("right down");
        assert!(harness.take_events().is_empty());
    }

    fn assert_change(events: Vec<crate::NativeEvent>, event_name: &str, expected: &str) {
        assert!(matches!(
            events.as_slice(),
            [crate::NativeEvent::Input {
                kind: crate::InputKind::Change,
                window_id: 7,
                event,
                value: Some(crate::EventValue::String(value)),
            }] if event == event_name && value == expected
        ));
    }

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
