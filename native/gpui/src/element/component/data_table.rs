use crate::element::ElementRenderContext;
use crate::{gpui, DataTableComponentNode, TableColumnComponentNode, TableRowComponentNode};

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
pub(crate) struct ComponentDataTable {
    pub(crate) collection: super::uniform_collection::ComponentUniformCollection,
    horizontal_scroll_handle: gpui::ScrollHandle,
}

#[cfg(feature = "components")]
impl ComponentDataTable {
    pub(crate) fn new(cx: &mut gpui::Context<'_, crate::ElixirRoot>) -> Self {
        Self {
            collection: super::uniform_collection::ComponentUniformCollection::new(cx),
            horizontal_scroll_handle: gpui::ScrollHandle::new(),
        }
    }
}

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct TableColumn {
    id: String,
    label: String,
    width: f32,
    align: String,
    sortable: bool,
    style: crate::StyleAttrs,
}

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct TableRow {
    id: String,
    disabled: bool,
    style: crate::StyleAttrs,
    cells: Vec<ElementNode>,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct VisibleTable {
    id: String,
    columns: Arc<Vec<TableColumn>>,
    rows: Arc<Vec<TableRow>>,
    offset: usize,
    total_count: usize,
    overscan: usize,
    selected: Option<String>,
    change_event: Option<String>,
    cell_change_event: Option<String>,
    range_event: Option<String>,
    item_height: f32,
    content_width: f32,
    selected_background: gpui::Hsla,
    selected_foreground: gpui::Hsla,
    border: gpui::Hsla,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct TableKey {
    id: String,
    disabled: bool,
    index: usize,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: DataTableComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        uniform_list, InteractiveElement, IntoElement, ParentElement, Role,
        StatefulInteractiveElement, Styled,
    };
    use gpui_component::{
        scroll::{ScrollableElement, ScrollableMask},
        ActiveTheme,
    };

    let mut columns = Vec::new();
    let mut rows = Vec::new();
    for child in node.children {
        match child {
            ElementNode::TableColumnComponent(column) => columns.push(TableColumn {
                id: column.id,
                label: column.label,
                width: column.width as f32,
                align: column.align.unwrap_or_else(|| "left".to_string()),
                sortable: column.sortable,
                style: column.style,
            }),
            ElementNode::TableRowComponent(row) => rows.push(TableRow {
                id: row.id,
                disabled: row.disabled,
                style: row.style,
                cells: row.children,
            }),
            _other => {}
        }
    }

    let total_count = usize::try_from(node.total_count).unwrap_or(usize::MAX);
    let offset = usize::try_from(node.offset)
        .unwrap_or(usize::MAX)
        .min(total_count);
    let overscan = usize::try_from(node.overscan).unwrap_or(usize::MAX);
    let keys = rows
        .iter()
        .enumerate()
        .map(|(local_index, row)| TableKey {
            id: row.id.clone(),
            disabled: row.disabled,
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

    if context.components.data_table_mut(&node.id).is_none() {
        let component = ComponentDataTable::new(context.cx);
        context.components.insert_data_table(&node.id, component);
    }
    let component = context
        .components
        .data_table_mut(&node.id)
        .expect("data table component must exist after insertion");
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
    component
        .collection
        .reconcile_reveal(reveal, node.reveal_strategy.as_deref());
    component
        .collection
        .reset_range_without_event(node.range.as_deref());

    let vertical_scroll = component.collection.scroll_handle.clone();
    let horizontal_scroll = component.horizontal_scroll_handle.clone();
    let focus_handle = component.collection.focus_handle.clone();
    let content_width = columns.iter().map(|column| column.width).sum::<f32>();
    let columns = Arc::new(columns);
    let rows = Arc::new(rows);
    let theme = context.cx.theme();
    let visible = VisibleTable {
        id: node.id.clone(),
        columns: columns.clone(),
        rows: rows.clone(),
        offset,
        total_count,
        overscan,
        selected: node.selected.clone(),
        change_event: node.change.clone(),
        cell_change_event: node.cell_change.clone(),
        range_event: node.range.clone(),
        item_height: (node.item_height as f32).max(1.0),
        content_width,
        selected_background: gpui::rgb(0x1D4ED8).into(),
        selected_foreground: gpui::white(),
        border: theme.border,
    };
    let processor = context.cx.processor(move |root, range, window, cx| {
        render_visible_rows(root, &visible, range, window, cx)
    });

    let header = render_header(
        &columns,
        node.sort_column.as_deref(),
        node.sort_direction.as_deref(),
        node.sort.as_deref(),
        &context.runtime,
        context.window_id,
        node.header_height as f32,
        theme.secondary,
        theme.secondary_foreground,
        theme.border,
    );
    let table_id = node.id.clone();
    let content = gpui::div()
        .w(gpui::px(content_width))
        .min_w_full()
        .h_full()
        .flex()
        .flex_col()
        .child(header)
        .child(
            uniform_list(
                format!(
                    "gpui-elixir-data-table-list-{}-{table_id}",
                    context.window_id
                ),
                total_count,
                processor,
            )
            .track_scroll(&vertical_scroll)
            .flex_1()
            .min_h_0(),
        );
    let viewport = gpui::div()
        .id(format!(
            "gpui-elixir-data-table-horizontal-{}-{table_id}",
            context.window_id
        ))
        .size_full()
        .relative()
        .overflow_hidden()
        .track_scroll(&horizontal_scroll)
        .child(content)
        .child(ScrollableMask::new(
            gpui::Axis::Horizontal,
            &horizontal_scroll,
        ))
        .horizontal_scrollbar(&horizontal_scroll);

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let cell_change_event = node.cell_change.clone();
    let key_rows = keys.clone();
    let key_columns = columns.clone();
    let key_scroll = vertical_scroll.clone();
    let selected_position =
        selected_index.and_then(|index| keys.iter().position(|key| key.index == index));
    let selected_column = node
        .selected_column
        .as_deref()
        .and_then(|id| columns.iter().position(|column| column.id == id))
        .unwrap_or(0)
        .min(columns.len().saturating_sub(1));
    let disabled = node.disabled;

    let container = apply_generated_render_styles(gpui::div(), node.style).id(table_id.clone());
    crate::element::register_test_target(container, table_id, Some(focus_handle.clone()), context)
        .role(Role::Grid)
        .aria_label(node.label.unwrap_or_else(|| "Data table".to_string()))
        .aria_row_count(total_count.saturating_add(1))
        .aria_column_count(columns.len())
        .track_focus(&focus_handle.tab_stop(!disabled))
        .on_key_down(move |event, window, cx| {
            if disabled || key_rows.is_empty() || key_columns.is_empty() {
                return;
            }
            let key = event.keystroke.key.as_str();
            if key == "left" || key == "right" {
                let column = if key == "left" {
                    selected_column.saturating_sub(1)
                } else {
                    selected_column
                        .saturating_add(1)
                        .min(key_columns.len().saturating_sub(1))
                };
                if let Some(row) = selected_position.and_then(|position| key_rows.get(position)) {
                    super::uniform_collection::emit_cell_change(
                        &runtime,
                        window_id,
                        cell_change_event.as_deref(),
                        &row.id,
                        &key_columns[column].id,
                    );
                    cx.stop_propagation();
                }
                return;
            }

            let Some(position) = key_target(key, &key_rows, selected_position, total_count) else {
                return;
            };
            let row = &key_rows[position];
            super::uniform_collection::emit_change(
                &runtime,
                window_id,
                change_event.as_deref(),
                &row.id,
            );
            super::uniform_collection::emit_cell_change(
                &runtime,
                window_id,
                cell_change_event.as_deref(),
                &row.id,
                &key_columns[selected_column].id,
            );
            key_scroll.scroll_to_item(row.index, gpui::ScrollStrategy::Nearest);
            window.refresh();
            cx.stop_propagation();
        })
        .child(viewport)
        .into_any_element()
}

#[cfg(feature = "components")]
#[allow(clippy::too_many_arguments)]
fn render_header(
    columns: &[TableColumn],
    sort_column: Option<&str>,
    sort_direction: Option<&str>,
    sort_event: Option<&str>,
    runtime: &crate::SharedRuntime,
    window_id: u64,
    height: f32,
    background: gpui::Hsla,
    foreground: gpui::Hsla,
    border: gpui::Hsla,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };

    let mut header = gpui::div()
        .id(format!("gpui-elixir-table-header-{window_id}"))
        .h(gpui::px(height.max(1.0)))
        .flex_none()
        .flex()
        .role(Role::Row)
        .aria_row_index(1)
        .bg(background)
        .border_b_1()
        .border_color(border);
    for (index, column) in columns.iter().enumerate() {
        let indicator = if sort_column == Some(column.id.as_str()) {
            match sort_direction {
                Some("ascending") => " ▲",
                Some("descending") => " ▼",
                _other => "",
            }
        } else {
            ""
        };
        let label = format!("{}{}", column.label, indicator);
        let cell = align_cell(
            apply_generated_render_styles(gpui::div(), column.style.clone())
                .w(gpui::px(column.width))
                .h_full()
                .flex_none()
                .items_center()
                .px_3()
                .text_color(foreground),
            &column.align,
        );
        let mut cell = cell
            .id(format!(
                "gpui-elixir-table-header-{window_id}-{}",
                column.id
            ))
            .role(Role::ColumnHeader)
            .aria_column_index(index.saturating_add(1))
            .child(label);
        if column.sortable {
            let runtime = runtime.clone();
            let event = sort_event.map(str::to_string);
            let column_id = column.id.clone();
            cell = cell.cursor(gpui::CursorStyle::PointingHand).on_click(
                move |_event, _window, _cx| {
                    super::uniform_collection::emit_change(
                        &runtime,
                        window_id,
                        event.as_deref(),
                        &column_id,
                    );
                },
            );
        }
        header = header.child(cell);
    }
    header.into_any_element()
}

#[cfg(feature = "components")]
fn render_visible_rows(
    root: &mut crate::ElixirRoot,
    table: &VisibleTable,
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
    let Some(component) = root.components.data_table_mut(&table.id) else {
        return Vec::new();
    };
    let requested_range = range.start.saturating_sub(table.overscan)
        ..range
            .end
            .saturating_add(table.overscan)
            .min(table.total_count);
    super::uniform_collection::schedule_range(
        &mut component.collection,
        super::uniform_collection::CollectionKind::DataTable,
        &table.id,
        requested_range,
        table.range_event.as_deref(),
        &runtime,
        window_id,
        window,
        cx,
    );

    component.collection.components.begin_render();
    let mut active_input_ids = HashSet::new();
    let mut rendered = Vec::new();
    for index in range {
        let row = index
            .checked_sub(table.offset)
            .and_then(|local_index| table.rows.get(local_index))
            .cloned();
        let Some(row) = row else {
            rendered.push(
                gpui::div()
                    .h(gpui::px(table.item_height))
                    .w(gpui::px(table.content_width))
                    .into_any_element(),
            );
            continue;
        };

        let selected = table.selected.as_deref() == Some(row.id.as_str());
        let row_id = row.id.clone();
        let row_disabled = row.disabled;
        let mut row_element = apply_generated_render_styles(gpui::div(), row.style)
            .id(format!(
                "gpui-elixir-table-row-{window_id}-{}-{row_id}",
                table.id
            ))
            .w(gpui::px(table.content_width))
            .h(gpui::px(table.item_height))
            .flex()
            .role(Role::Row)
            .aria_row_index(index.saturating_add(2))
            .aria_selected(selected)
            .border_b_1()
            .border_color(table.border);
        if selected {
            row_element = row_element
                .bg(table.selected_background)
                .text_color(table.selected_foreground)
                .aria_active_descendant();
        }

        for (column_index, (column, cell)) in table.columns.iter().zip(row.cells).enumerate() {
            let cell_child = {
                let mut cell_context = ElementRenderContext {
                    runtime: runtime.clone(),
                    window_id,
                    next_element_id: 0,
                    id_namespace: format!("table-{}-{}-{}", table.id, row_id, column.id),
                    active_input_ids: &mut active_input_ids,
                    input_entities: &mut component.collection.input_entities,
                    components: &mut component.collection.components,
                    window,
                    cx,
                };
                cell.render(&mut cell_context)
            };
            let runtime = runtime.clone();
            let change_event = table.change_event.clone();
            let cell_change_event = table.cell_change_event.clone();
            let event_row = row_id.clone();
            let event_column = column.id.clone();
            let focus = component.collection.focus_handle.clone();
            let cell_element = align_cell(
                gpui::div()
                    .w(gpui::px(column.width))
                    .h_full()
                    .flex_none()
                    .items_center()
                    .px_3(),
                &column.align,
            );
            let mut cell_element = cell_element
                .id(format!(
                    "gpui-elixir-table-cell-{window_id}-{}-{row_id}-{}",
                    table.id, column.id
                ))
                .role(Role::GridCell)
                .aria_column_index(column_index.saturating_add(1))
                .child(cell_child);
            if !row_disabled {
                cell_element = cell_element
                    .cursor(gpui::CursorStyle::PointingHand)
                    .on_click(move |_event, window, cx| {
                        focus.focus(window, cx);
                        super::uniform_collection::emit_change(
                            &runtime,
                            window_id,
                            change_event.as_deref(),
                            &event_row,
                        );
                        super::uniform_collection::emit_cell_change(
                            &runtime,
                            window_id,
                            cell_change_event.as_deref(),
                            &event_row,
                            &event_column,
                        );
                    });
            }
            row_element = row_element.child(cell_element);
        }
        rendered.push(row_element.into_any_element());
    }

    component
        .collection
        .input_entities
        .retain(|input_id, _entity| active_input_ids.contains(input_id));
    component.collection.components.finish_render(window, cx);
    rendered
}

#[cfg(feature = "components")]
fn align_cell(mut cell: gpui::Div, align: &str) -> gpui::Div {
    use gpui::Styled;

    cell = cell.flex();
    match align {
        "right" => cell.justify_end(),
        "center" => cell.justify_center(),
        _other => cell.justify_start(),
    }
}

#[cfg(feature = "components")]
fn key_target(
    key: &str,
    rows: &[TableKey],
    selected: Option<usize>,
    total_count: usize,
) -> Option<usize> {
    super::uniform_collection::linear_key_target(
        key,
        rows,
        selected,
        total_count,
        |row| row.index,
        |row| row.disabled,
    )
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: DataTableComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(feature = "components")]
pub(crate) fn render_column(
    node: TableColumnComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    crate::element::apply_generated_render_styles(gpui::div(), node.style)
        .child(node.label)
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_column(
    node: TableColumnComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.label), Vec::new(), context)
}

#[cfg(feature = "components")]
pub(crate) fn render_row(
    node: TableRowComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    let children = node
        .children
        .into_iter()
        .map(|child| child.render(context))
        .collect::<Vec<_>>();
    crate::element::apply_generated_render_styles(gpui::div(), node.style)
        .children(children)
        .into_any_element()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_row(
    node: TableRowComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, None, node.children, context)
}
