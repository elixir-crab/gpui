#![cfg(feature = "components")]

use crate::element::component_registry::ComponentRegistry;
use crate::{gpui, NativeTextInput};
use std::collections::HashMap;
use std::ops::Range;

pub(crate) struct ComponentUniformCollection {
    pub(crate) scroll_handle: gpui::UniformListScrollHandle,
    pub(crate) focus_handle: gpui::FocusHandle,
    pub(crate) last_reveal: Option<(String, usize)>,
    pub(crate) last_requested_range: Option<Range<usize>>,
    pub(crate) pending_requested_range: Option<Range<usize>>,
    pub(crate) range_emit_scheduled: bool,
    pub(crate) input_entities: HashMap<String, gpui::Entity<NativeTextInput>>,
    pub(crate) components: ComponentRegistry,
}

impl ComponentUniformCollection {
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

    pub(crate) fn reconcile_reveal(
        &mut self,
        reveal: Option<(String, usize)>,
        strategy: Option<&str>,
    ) {
        if self.last_reveal == reveal {
            return;
        }
        self.last_reveal = reveal.clone();
        if let Some((_id, index)) = reveal {
            self.scroll_handle
                .scroll_to_item(index, scroll_strategy(strategy));
        }
    }

    pub(crate) fn reset_range_without_event(&mut self, range_event: Option<&str>) {
        if range_event.is_none() {
            self.last_requested_range = None;
        }
    }
}

pub(crate) fn controlled_index(
    total_count: usize,
    index: Option<u64>,
    value: Option<&str>,
    find_loaded: impl FnOnce(&str) -> Option<usize>,
) -> Option<usize> {
    index
        .and_then(|index| usize::try_from(index).ok())
        .filter(|index| *index < total_count)
        .or_else(|| value.and_then(find_loaded))
}

pub(crate) fn linear_key_target<T>(
    key: &str,
    items: &[T],
    selected: Option<usize>,
    total_count: usize,
    index: impl Fn(&T) -> usize,
    disabled: impl Fn(&T) -> bool,
) -> Option<usize> {
    match key {
        "down" => next_enabled(
            items,
            selected.map_or(0, |position| position.saturating_add(1)),
            &disabled,
        ),
        "up" => previous_enabled(items, selected.unwrap_or(items.len()), &disabled),
        "home" => items
            .iter()
            .position(|item| index(item) == 0 && !disabled(item)),
        "end" => items
            .iter()
            .rposition(|item| index(item).saturating_add(1) == total_count && !disabled(item)),
        "enter" | "space" => {
            selected.filter(|position| items.get(*position).is_some_and(|item| !disabled(item)))
        }
        _other => None,
    }
}

pub(crate) fn next_enabled<T>(
    items: &[T],
    start: usize,
    disabled: impl Fn(&T) -> bool,
) -> Option<usize> {
    (start..items.len()).find(|position| !disabled(&items[*position]))
}

pub(crate) fn previous_enabled<T>(
    items: &[T],
    end: usize,
    disabled: impl Fn(&T) -> bool,
) -> Option<usize> {
    let end = end.min(items.len());
    (0..end).rev().find(|position| !disabled(&items[*position]))
}

pub(crate) fn controlled_reveal(
    total_count: usize,
    index: Option<u64>,
    value: Option<&str>,
    find_loaded: impl FnOnce(&str) -> Option<usize>,
) -> Option<(String, usize)> {
    index
        .and_then(|index| usize::try_from(index).ok())
        .filter(|index| *index < total_count)
        .map(|index| {
            (
                value
                    .map(str::to_string)
                    .unwrap_or_else(|| format!("index-{index}")),
                index,
            )
        })
        .or_else(|| {
            value.and_then(|value| find_loaded(value).map(|index| (value.to_string(), index)))
        })
}

#[derive(Clone, Copy)]
pub(crate) enum CollectionKind {
    List,
    Tree,
    CodeViewer,
    DataTable,
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn schedule_range(
    component: &mut ComponentUniformCollection,
    kind: CollectionKind,
    collection_id: &str,
    requested_range: Range<usize>,
    event: Option<&str>,
    runtime: &crate::SharedRuntime,
    window_id: u64,
    window: &gpui::Window,
    cx: &mut gpui::Context<'_, crate::ElixirRoot>,
) {
    let Some(event) = event else {
        return;
    };

    component.pending_requested_range = Some(requested_range);
    if component.range_emit_scheduled {
        return;
    }
    component.range_emit_scheduled = true;

    let collection_id = collection_id.to_string();
    let event = event.to_string();
    let runtime = runtime.clone();
    cx.defer_in(window, move |root, _window, _cx| {
        let component = match kind {
            CollectionKind::List => root.components.virtual_list_mut(&collection_id),
            CollectionKind::Tree => root.components.tree_mut(&collection_id),
            CollectionKind::CodeViewer => root
                .components
                .code_viewer_mut(&collection_id)
                .map(|component| &mut component.collection),
            CollectionKind::DataTable => root
                .components
                .data_table_mut(&collection_id)
                .map(|component| &mut component.collection),
        };
        let Some(component) = component else {
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

pub(crate) fn emit_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&str>,
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
            event: event.to_string(),
            value: Some(EventValue::String(value.to_string())),
        },
    );
}

pub(crate) fn emit_cell_change(
    runtime: &crate::SharedRuntime,
    window_id: u64,
    event: Option<&str>,
    row_id: &str,
    column_id: &str,
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
            event: event.to_string(),
            value: Some(EventValue::Strings(vec![
                row_id.to_string(),
                column_id.to_string(),
            ])),
        },
    );
}

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

fn scroll_strategy(strategy: Option<&str>) -> gpui::ScrollStrategy {
    match strategy {
        Some("top") => gpui::ScrollStrategy::Top,
        Some("center") => gpui::ScrollStrategy::Center,
        Some("bottom") => gpui::ScrollStrategy::Bottom,
        _other => gpui::ScrollStrategy::Nearest,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Clone, Copy)]
    struct Item {
        index: usize,
        disabled: bool,
    }

    #[test]
    fn linear_navigation_skips_disabled_items_and_requires_loaded_endpoints() {
        let items = [
            Item {
                index: 40,
                disabled: false,
            },
            Item {
                index: 41,
                disabled: true,
            },
            Item {
                index: 42,
                disabled: false,
            },
        ];
        let target = |key, selected| {
            linear_key_target(
                key,
                &items,
                selected,
                100,
                |item| item.index,
                |item| item.disabled,
            )
        };

        assert_eq!(target("down", Some(0)), Some(2));
        assert_eq!(target("up", Some(2)), Some(0));
        assert_eq!(target("enter", Some(1)), None);
        assert_eq!(target("home", None), None);
        assert_eq!(target("end", None), None);
    }
}
