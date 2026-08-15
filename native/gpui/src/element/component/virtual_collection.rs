use crate::element::ElementRenderContext;
use crate::{gpui, VirtualCollectionComponentNode, VirtualItemComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;
#[cfg(feature = "components")]
use crate::element::ElementNode;

#[cfg(feature = "components")]
pub(crate) struct ComponentVirtualCollection {
    pub(crate) list_state: gpui::ListState,
    item_keys: Vec<(String, u64)>,
    alignment: String,
    overdraw: f32,
    last_reveal_request: u64,
    last_follow_request: u64,
    follow: String,
    range_event: Option<String>,
    last_visible_range: std::sync::Arc<std::sync::Mutex<Option<std::ops::Range<usize>>>>,
    item_states: std::collections::HashMap<String, VirtualItemState>,
}

#[cfg(feature = "components")]
#[derive(Default)]
struct VirtualItemState {
    input_entities: std::collections::HashMap<String, gpui::Entity<crate::NativeTextInput>>,
    components: crate::element::component_registry::ComponentRegistry,
}

#[cfg(feature = "components")]
impl ComponentVirtualCollection {
    fn new(node: &VirtualCollectionComponentNode) -> Self {
        let alignment = alignment(node.alignment.as_deref());
        let overdraw = (node.overdraw as f32).clamp(0.0, 4096.0);
        let list_state = gpui::ListState::new(node.children.len(), alignment, gpui::px(overdraw));
        Self {
            list_state,
            item_keys: Vec::new(),
            alignment: node.alignment.clone().unwrap_or_else(|| "top".to_string()),
            overdraw,
            last_reveal_request: 0,
            last_follow_request: 0,
            follow: "none".to_string(),
            range_event: node.range.clone(),
            last_visible_range: std::sync::Arc::new(std::sync::Mutex::new(None)),
            item_states: std::collections::HashMap::new(),
        }
    }

    fn reconcile(
        &mut self,
        node: &VirtualCollectionComponentNode,
        item_keys: Vec<(String, u64)>,
    ) -> bool {
        let next_alignment = node.alignment.as_deref().unwrap_or("top");
        let next_overdraw = (node.overdraw as f32).clamp(0.0, 4096.0);
        if self.alignment != next_alignment || self.overdraw != next_overdraw {
            return false;
        }

        reconcile_item_keys(&self.list_state, &self.item_keys, &item_keys);
        self.item_states
            .retain(|id, _state| item_keys.iter().any(|(item_id, _revision)| item_id == id));
        self.item_keys = item_keys;

        if self.range_event != node.range {
            self.range_event = node.range.clone();
            if let Ok(mut last_range) = self.last_visible_range.lock() {
                *last_range = None;
            }
        }

        let next_follow = node.follow.as_deref().unwrap_or("none");
        if self.follow != next_follow {
            self.list_state.set_follow_mode(follow_mode(next_follow));
            self.follow = next_follow.to_string();
        }
        if node.follow_request > self.last_follow_request {
            self.list_state.set_follow_mode(follow_mode(next_follow));
            if next_follow == "tail" {
                self.list_state.scroll_to_end();
            }
            self.last_follow_request = node.follow_request;
        }

        if node.reveal_request > self.last_reveal_request {
            if let Some(index) = node.reveal.as_deref().and_then(|id| {
                self.item_keys
                    .iter()
                    .position(|(item_id, _revision)| item_id == id)
            }) {
                reveal_item(&self.list_state, index, node.reveal_strategy.as_deref());
            }
            self.last_reveal_request = node.reveal_request;
        }
        true
    }
}

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct VariableItem {
    id: String,
    revision: u64,
    style: crate::StyleAttrs,
    children: Vec<ElementNode>,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: VirtualCollectionComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        list, InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement,
        Styled,
    };
    use std::sync::Arc;

    let items = node
        .children
        .iter()
        .filter_map(|child| match child {
            ElementNode::VirtualItemComponent(item) => Some(VariableItem {
                id: item.id.clone(),
                revision: item.revision,
                style: item.style.clone(),
                children: item.children.clone(),
            }),
            _other => None,
        })
        .collect::<Vec<_>>();
    let item_keys = items
        .iter()
        .map(|item| (item.id.clone(), item.revision))
        .collect::<Vec<_>>();

    let keep = context
        .components
        .virtual_collection_mut(&node.id)
        .is_some_and(|component| component.reconcile(&node, item_keys.clone()));
    if !keep {
        let mut component = ComponentVirtualCollection::new(&node);
        component.item_keys = item_keys;
        component.follow = node.follow.clone().unwrap_or_else(|| "none".to_string());
        component
            .list_state
            .set_follow_mode(follow_mode(component.follow.as_str()));
        component.last_follow_request = node.follow_request;
        if node.reveal_request > 0 {
            if let Some(index) = node.reveal.as_deref().and_then(|id| {
                component
                    .item_keys
                    .iter()
                    .position(|(item_id, _revision)| item_id == id)
            }) {
                reveal_item(
                    &component.list_state,
                    index,
                    node.reveal_strategy.as_deref(),
                );
            }
            component.last_reveal_request = node.reveal_request;
        }
        context
            .components
            .insert_virtual_collection(&node.id, component);
    }

    let component = context
        .components
        .virtual_collection_mut(&node.id)
        .expect("virtual collection must exist after insertion");
    let list_state = component.list_state.clone();
    install_scroll_handler(
        &list_state,
        context.runtime.clone(),
        context.window_id,
        node.range.clone(),
        component.last_visible_range.clone(),
    );
    schedule_visible_range(
        &list_state,
        node.children.len(),
        context.runtime.clone(),
        context.window_id,
        node.range.clone(),
        component.last_visible_range.clone(),
        context.window,
        context.cx,
    );

    let items = Arc::new(items);
    let collection_id = node.id.clone();
    let processor = context.cx.processor(move |root, index, window, cx| {
        render_variable_item(root, &collection_id, &items[index], window, cx)
    });

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .role(Role::List)
        .aria_label(node.label.unwrap_or_else(|| "Items".to_string()))
        .child(list(list_state, processor).size_full())
        .into_any_element()
}

#[cfg(feature = "components")]
fn render_variable_item(
    root: &mut crate::ElixirRoot,
    collection_id: &str,
    item: &VariableItem,
    window: &mut gpui::Window,
    cx: &mut gpui::Context<'_, crate::ElixirRoot>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement};
    use std::collections::HashSet;

    let runtime = root.runtime.clone();
    let window_id = root.window_id;
    let component = root
        .components
        .virtual_collection_mut(collection_id)
        .expect("active variable collection state must exist");
    let item_state = component.item_states.entry(item.id.clone()).or_default();
    item_state.components.begin_render();
    let mut active_input_ids = HashSet::new();
    let children = {
        let mut item_context = ElementRenderContext {
            runtime: runtime.clone(),
            window_id,
            next_element_id: 0,
            id_namespace: format!("variable-{collection_id}-{}", item.id),
            active_input_ids: &mut active_input_ids,
            input_entities: &mut item_state.input_entities,
            components: &mut item_state.components,
            window,
            cx,
        };
        item.children
            .clone()
            .into_iter()
            .map(|child| child.render(&mut item_context))
            .collect::<Vec<_>>()
    };
    item_state
        .input_entities
        .retain(|input_id, _entity| active_input_ids.contains(input_id));
    item_state.components.finish_render(window, cx);

    apply_generated_render_styles(gpui::div(), item.style.clone())
        .id(format!(
            "gpui-elixir-variable-item-{window_id}-{collection_id}-{}",
            item.id
        ))
        .role(Role::ListItem)
        .children(children)
        .into_any_element()
}

#[cfg(feature = "components")]
fn reconcile_item_keys(state: &gpui::ListState, old: &[(String, u64)], new: &[(String, u64)]) {
    let Some(change) = item_key_change(old, new) else {
        return;
    };
    state.splice(change.old_range, change.new_count);
}

#[cfg(any(feature = "components", test))]
#[derive(Debug, Eq, PartialEq)]
struct ItemKeyChange {
    old_range: std::ops::Range<usize>,
    new_count: usize,
}

#[cfg(any(feature = "components", test))]
fn item_key_change(old: &[(String, u64)], new: &[(String, u64)]) -> Option<ItemKeyChange> {
    if old == new {
        return None;
    }

    let prefix = old
        .iter()
        .zip(new.iter())
        .take_while(|(old, new)| old == new)
        .count();
    let suffix = old[prefix..]
        .iter()
        .rev()
        .zip(new[prefix..].iter().rev())
        .take_while(|(old, new)| old == new)
        .count();
    Some(ItemKeyChange {
        old_range: prefix..old.len().saturating_sub(suffix),
        new_count: new.len() - prefix - suffix,
    })
}

#[cfg(feature = "components")]
fn install_scroll_handler(
    state: &gpui::ListState,
    runtime: crate::SharedRuntime,
    window_id: u64,
    event: Option<String>,
    last_visible_range: std::sync::Arc<std::sync::Mutex<Option<std::ops::Range<usize>>>>,
) {
    state.set_scroll_handler(move |scroll, _window, _cx| {
        let Some(event) = event.as_deref() else {
            return;
        };
        emit_visible_range(
            &runtime,
            window_id,
            event,
            scroll.visible_range.clone(),
            &last_visible_range,
        );
    });
}

#[cfg(feature = "components")]
#[allow(clippy::too_many_arguments)]
fn schedule_visible_range(
    state: &gpui::ListState,
    item_count: usize,
    runtime: crate::SharedRuntime,
    window_id: u64,
    event: Option<String>,
    last_visible_range: std::sync::Arc<std::sync::Mutex<Option<std::ops::Range<usize>>>>,
    window: &gpui::Window,
    cx: &mut gpui::Context<'_, crate::ElixirRoot>,
) {
    let state = state.clone();
    cx.defer_in(window, move |_root, _window, _cx| {
        let Some(event) = event.as_deref() else {
            return;
        };
        let viewport = state.viewport_bounds();
        let start = state.logical_scroll_top().item_ix.min(item_count);
        let mut end = start;
        while end < item_count {
            let Some(bounds) = state.bounds_for_item(end) else {
                break;
            };
            if bounds.top() >= viewport.bottom() {
                break;
            }
            end += 1;
        }
        emit_visible_range(&runtime, window_id, event, start..end, &last_visible_range);
    });
}

#[cfg(feature = "components")]
fn emit_visible_range(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: &str,
    range: std::ops::Range<usize>,
    last_visible_range: &std::sync::Arc<std::sync::Mutex<Option<std::ops::Range<usize>>>>,
) {
    let mut last_range = match last_visible_range.lock() {
        Ok(last_range) => last_range,
        Err(_poisoned) => return,
    };
    if last_range.as_ref() == Some(&range) {
        return;
    }
    *last_range = Some(range.clone());
    let _ = crate::push_event(
        runtime,
        crate::NativeEvent::VirtualRange {
            window_id,
            event: event.to_string(),
            first: range.start as u64,
            last: range.end as u64,
        },
    );
}

#[cfg(feature = "components")]
fn alignment(value: Option<&str>) -> gpui::ListAlignment {
    match value {
        Some("bottom") => gpui::ListAlignment::Bottom,
        _other => gpui::ListAlignment::Top,
    }
}

#[cfg(feature = "components")]
fn follow_mode(value: &str) -> gpui::FollowMode {
    match value {
        "tail" => gpui::FollowMode::Tail,
        _other => gpui::FollowMode::Normal,
    }
}

#[cfg(feature = "components")]
fn reveal_item(state: &gpui::ListState, index: usize, strategy: Option<&str>) {
    match strategy {
        Some("top") => state.scroll_to(gpui::ListOffset {
            item_ix: index,
            offset_in_item: gpui::px(0.0),
        }),
        _other => state.scroll_to_reveal_item(index),
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: VirtualCollectionComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(feature = "components")]
pub(crate) fn render_item(
    node: VirtualItemComponentNode,
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

#[cfg(test)]
mod tests {
    use super::*;

    fn keys(values: &[(&str, u64)]) -> Vec<(String, u64)> {
        values
            .iter()
            .map(|(id, revision)| ((*id).to_string(), *revision))
            .collect()
    }

    #[test]
    fn item_diff_preserves_unchanged_prefix_and_suffix() {
        let old = keys(&[("a", 0), ("b", 0), ("c", 0)]);

        assert_eq!(item_key_change(&old, &old), None);
        assert_eq!(
            item_key_change(&old, &keys(&[("a", 0), ("b", 0), ("c", 0), ("d", 0)])),
            Some(ItemKeyChange {
                old_range: 3..3,
                new_count: 1
            })
        );
        assert_eq!(
            item_key_change(&old, &keys(&[("z", 0), ("a", 0), ("b", 0), ("c", 0)])),
            Some(ItemKeyChange {
                old_range: 0..0,
                new_count: 1
            })
        );
        assert_eq!(
            item_key_change(&old, &keys(&[("a", 0), ("b", 1), ("c", 0)])),
            Some(ItemKeyChange {
                old_range: 1..2,
                new_count: 1
            })
        );
        assert_eq!(
            item_key_change(&old, &keys(&[("a", 0), ("c", 0)])),
            Some(ItemKeyChange {
                old_range: 1..2,
                new_count: 0
            })
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn variable_list_measures_heights_and_remeasures_revised_items(cx: &mut gpui::TestAppContext) {
        use gpui::{AppContext, IntoElement, Render, Styled};
        use std::{cell::Cell, rc::Rc};

        struct TestView {
            heights: Rc<Cell<[f32; 3]>>,
            state: gpui::ListState,
        }

        impl Render for TestView {
            fn render(
                &mut self,
                _window: &mut gpui::Window,
                _cx: &mut gpui::Context<Self>,
            ) -> impl IntoElement {
                let heights = self.heights.clone();
                gpui::list(self.state.clone(), move |index, _window, _cx| {
                    gpui::div()
                        .h(gpui::px(heights.get()[index]))
                        .w_full()
                        .into_any_element()
                })
                .size_full()
            }
        }

        let cx = cx.add_empty_window();
        let heights = Rc::new(Cell::new([40.0_f32, 80.0_f32, 120.0_f32]));
        let state = gpui::ListState::new(3, gpui::ListAlignment::Top, gpui::px(0.0));
        let draw = |cx: &mut gpui::VisualTestContext,
                    heights: Rc<Cell<[f32; 3]>>,
                    state: gpui::ListState,
                    viewport_height: f32| {
            cx.draw(
                gpui::point(gpui::px(0.0), gpui::px(0.0)),
                gpui::size(gpui::px(200.0), gpui::px(viewport_height)),
                move |_window, cx| cx.new(|_| TestView { heights, state }).into_any_element(),
            );
        };

        draw(cx, heights.clone(), state.clone(), 300.0);
        assert_eq!(
            state.bounds_for_item(0).unwrap().size.height,
            gpui::px(40.0)
        );
        assert_eq!(
            state.bounds_for_item(1).unwrap().size.height,
            gpui::px(80.0)
        );
        assert_eq!(
            state.bounds_for_item(2).unwrap().size.height,
            gpui::px(120.0)
        );

        heights.set([40.0, 160.0, 120.0]);
        let old = keys(&[("a", 0), ("b", 0), ("c", 0)]);
        let new = keys(&[("a", 0), ("b", 1), ("c", 0)]);
        reconcile_item_keys(&state, &old, &new);
        draw(cx, heights, state.clone(), 400.0);
        assert_eq!(
            state.bounds_for_item(0).unwrap().size.height,
            gpui::px(40.0)
        );
        assert_eq!(
            state.bounds_for_item(1).unwrap().size.height,
            gpui::px(160.0)
        );
        assert_eq!(
            state.bounds_for_item(2).unwrap().size.height,
            gpui::px(120.0)
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn growth_above_viewport_preserves_the_visible_scroll_anchor(cx: &mut gpui::TestAppContext) {
        use gpui::{AppContext, IntoElement, Render, Styled};
        use std::{cell::Cell, rc::Rc};

        struct TestView {
            first_height: Rc<Cell<f32>>,
            state: gpui::ListState,
        }

        impl Render for TestView {
            fn render(
                &mut self,
                _window: &mut gpui::Window,
                _cx: &mut gpui::Context<Self>,
            ) -> impl IntoElement {
                let first_height = self.first_height.clone();
                gpui::list(self.state.clone(), move |index, _window, _cx| {
                    let height = if index == 0 { first_height.get() } else { 40.0 };
                    gpui::div().h(gpui::px(height)).w_full().into_any_element()
                })
                .size_full()
            }
        }

        let cx = cx.add_empty_window();
        let first_height = Rc::new(Cell::new(40.0));
        let state = gpui::ListState::new(10, gpui::ListAlignment::Top, gpui::px(0.0));
        let draw = |cx: &mut gpui::VisualTestContext,
                    first_height: Rc<Cell<f32>>,
                    state: gpui::ListState| {
            cx.draw(
                gpui::point(gpui::px(0.0), gpui::px(0.0)),
                gpui::size(gpui::px(200.0), gpui::px(120.0)),
                move |_window, cx| {
                    cx.new(|_| TestView {
                        first_height,
                        state,
                    })
                    .into_any_element()
                },
            );
        };

        draw(cx, first_height.clone(), state.clone());
        state.scroll_to(gpui::ListOffset {
            item_ix: 4,
            offset_in_item: gpui::px(12.0),
        });
        draw(cx, first_height.clone(), state.clone());
        let anchor = state.logical_scroll_top();

        first_height.set(120.0);
        reconcile_item_keys(
            &state,
            &keys(&[
                ("a", 0),
                ("b", 0),
                ("c", 0),
                ("d", 0),
                ("e", 0),
                ("f", 0),
                ("g", 0),
                ("h", 0),
                ("i", 0),
                ("j", 0),
            ]),
            &keys(&[
                ("a", 1),
                ("b", 0),
                ("c", 0),
                ("d", 0),
                ("e", 0),
                ("f", 0),
                ("g", 0),
                ("h", 0),
                ("i", 0),
                ("j", 0),
            ]),
        );
        draw(cx, first_height, state.clone());

        assert_eq!(state.logical_scroll_top().item_ix, anchor.item_ix);
        assert_eq!(
            state.logical_scroll_top().offset_in_item,
            anchor.offset_in_item
        );
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn prepend_and_remove_rebase_a_detached_scroll_anchor(cx: &mut gpui::TestAppContext) {
        use gpui::{AppContext, IntoElement, Render, Styled};

        struct TestView {
            count: usize,
            state: gpui::ListState,
        }

        impl Render for TestView {
            fn render(
                &mut self,
                _window: &mut gpui::Window,
                _cx: &mut gpui::Context<Self>,
            ) -> impl IntoElement {
                let count = self.count;
                gpui::list(self.state.clone(), move |index, _window, _cx| {
                    assert!(index < count);
                    gpui::div().h(gpui::px(40.0)).w_full().into_any_element()
                })
                .size_full()
            }
        }

        let cx = cx.add_empty_window();
        let state = gpui::ListState::new(8, gpui::ListAlignment::Top, gpui::px(0.0));
        let draw = |cx: &mut gpui::VisualTestContext, state: gpui::ListState, count| {
            cx.draw(
                gpui::point(gpui::px(0.0), gpui::px(0.0)),
                gpui::size(gpui::px(200.0), gpui::px(120.0)),
                move |_window, cx| cx.new(|_| TestView { count, state }).into_any_element(),
            );
        };

        draw(cx, state.clone(), 8);
        state.scroll_to(gpui::ListOffset {
            item_ix: 4,
            offset_in_item: gpui::px(10.0),
        });
        draw(cx, state.clone(), 8);

        state.splice(0..0, 2);
        draw(cx, state.clone(), 10);
        assert_eq!(state.logical_scroll_top().item_ix, 6);
        assert_eq!(state.logical_scroll_top().offset_in_item, gpui::px(10.0));

        state.splice(0..2, 0);
        draw(cx, state.clone(), 8);
        assert_eq!(state.logical_scroll_top().item_ix, 4);
        assert_eq!(state.logical_scroll_top().offset_in_item, gpui::px(10.0));
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn empty_populated_empty_transitions_reset_without_stale_geometry(
        cx: &mut gpui::TestAppContext,
    ) {
        use gpui::{AppContext, IntoElement, Render, Styled};

        struct TestView {
            count: usize,
            state: gpui::ListState,
        }

        impl Render for TestView {
            fn render(
                &mut self,
                _window: &mut gpui::Window,
                _cx: &mut gpui::Context<Self>,
            ) -> impl IntoElement {
                let count = self.count;
                gpui::list(self.state.clone(), move |index, _window, _cx| {
                    assert!(index < count);
                    gpui::div().h(gpui::px(48.0)).w_full().into_any_element()
                })
                .size_full()
            }
        }

        let cx = cx.add_empty_window();
        let state = gpui::ListState::new(0, gpui::ListAlignment::Bottom, gpui::px(0.0));
        let draw = |cx: &mut gpui::VisualTestContext, state: gpui::ListState, count| {
            cx.draw(
                gpui::point(gpui::px(0.0), gpui::px(0.0)),
                gpui::size(gpui::px(200.0), gpui::px(120.0)),
                move |_window, cx| cx.new(|_| TestView { count, state }).into_any_element(),
            );
        };

        draw(cx, state.clone(), 0);
        assert_eq!(state.item_count(), 0);

        state.splice(0..0, 3);
        draw(cx, state.clone(), 3);
        assert_eq!(state.item_count(), 3);
        assert_eq!(state.max_offset_for_scrollbar().y, gpui::px(24.0));

        state.splice(0..3, 0);
        draw(cx, state.clone(), 0);
        assert_eq!(state.item_count(), 0);
        assert_eq!(state.max_offset_for_scrollbar().y, gpui::px(0.0));
    }

    #[cfg(feature = "components")]
    #[gpui::test]
    fn bottom_alignment_and_tail_follow_track_appended_items(cx: &mut gpui::TestAppContext) {
        use gpui::{AppContext, IntoElement, Render, Styled};

        struct TestView(gpui::ListState);

        impl Render for TestView {
            fn render(
                &mut self,
                _window: &mut gpui::Window,
                _cx: &mut gpui::Context<Self>,
            ) -> impl IntoElement {
                gpui::list(self.0.clone(), |_index, _window, _cx| {
                    gpui::div().h(gpui::px(40.0)).w_full().into_any_element()
                })
                .size_full()
            }
        }

        let cx = cx.add_empty_window();
        let state = gpui::ListState::new(2, gpui::ListAlignment::Bottom, gpui::px(0.0));
        state.set_follow_mode(gpui::FollowMode::Tail);
        let draw = |cx: &mut gpui::VisualTestContext, state: gpui::ListState| {
            cx.draw(
                gpui::point(gpui::px(0.0), gpui::px(0.0)),
                gpui::size(gpui::px(200.0), gpui::px(100.0)),
                move |_window, cx| cx.new(|_| TestView(state)).into_any_element(),
            );
        };

        draw(cx, state.clone());
        assert_eq!(state.logical_scroll_top().item_ix, 2);
        assert_eq!(state.scroll_px_offset_for_scrollbar().y, gpui::px(0.0));

        state.splice(2..2, 1);
        draw(cx, state.clone());
        assert!(state.is_following_tail());
        assert_eq!(state.logical_scroll_top().item_ix, 3);
        assert_eq!(state.scroll_px_offset_for_scrollbar().y, gpui::px(-20.0));
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_item(
    node: VirtualItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, None, node.children, context)
}
