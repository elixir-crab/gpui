use crate::element::ElementRenderContext;
use crate::{gpui, CodeLineComponentNode, CodeViewerComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;
#[cfg(feature = "components")]
use crate::element::ElementNode;

#[cfg(feature = "components")]
use std::ops::Range;
#[cfg(feature = "components")]
use std::sync::Arc;

#[cfg(feature = "components")]
pub(crate) struct ComponentCodeViewer {
    pub(crate) collection: super::uniform_collection::ComponentUniformCollection,
    horizontal_scroll_handle: gpui::ScrollHandle,
}

#[cfg(feature = "components")]
impl ComponentCodeViewer {
    pub(crate) fn new(cx: &mut gpui::Context<'_, crate::ElixirRoot>) -> Self {
        Self {
            collection: super::uniform_collection::ComponentUniformCollection::new(cx),
            horizontal_scroll_handle: gpui::ScrollHandle::new(),
        }
    }
}

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct CodeLine {
    id: String,
    text: String,
    number: Option<u64>,
    kind: String,
    disabled: bool,
    style: crate::StyleAttrs,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct VisibleCode {
    id: String,
    lines: Arc<Vec<CodeLine>>,
    offset: usize,
    total_count: usize,
    overscan: usize,
    selected: Option<String>,
    change_event: Option<String>,
    range_event: Option<String>,
    mode: String,
    show_line_numbers: bool,
    tab_width: usize,
    item_height: f32,
    dark: bool,
    background: gpui::Hsla,
    foreground: gpui::Hsla,
    muted_foreground: gpui::Hsla,
    selected_background: gpui::Hsla,
    selected_foreground: gpui::Hsla,
    mono_font_family: gpui::SharedString,
    mono_font_size: gpui::Pixels,
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct CodeKey {
    id: String,
    text: String,
    disabled: bool,
    index: usize,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: CodeViewerComponentNode,
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

    let tab_width = usize::try_from(node.tab_width).unwrap_or(4).clamp(1, 16);
    let lines = node
        .children
        .into_iter()
        .filter_map(|child| match child {
            ElementNode::CodeLineComponent(line) => Some(CodeLine {
                id: line.id,
                text: line.text,
                number: line.number,
                kind: line.kind.unwrap_or_else(|| "context".to_string()),
                disabled: line.disabled,
                style: line.style,
            }),
            _other => None,
        })
        .collect::<Vec<_>>();
    let total_count = usize::try_from(node.total_count).unwrap_or(usize::MAX);
    let offset = usize::try_from(node.offset)
        .unwrap_or(usize::MAX)
        .min(total_count);
    let overscan = usize::try_from(node.overscan).unwrap_or(usize::MAX);
    let keys = lines
        .iter()
        .enumerate()
        .map(|(local_index, line)| CodeKey {
            id: line.id.clone(),
            text: line.text.clone(),
            disabled: line.disabled,
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

    if context.components.code_viewer_mut(&node.id).is_none() {
        let component = ComponentCodeViewer::new(context.cx);
        context.components.insert_code_viewer(&node.id, component);
    }
    let component = context
        .components
        .code_viewer_mut(&node.id)
        .expect("code viewer component must exist after insertion");
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

    let loaded_columns = lines
        .iter()
        .map(|line| expanded_columns(&line.text, tab_width))
        .max()
        .unwrap_or(0);
    let max_columns = usize::try_from(node.max_columns)
        .unwrap_or(20_000)
        .min(20_000)
        .max(loaded_columns.min(20_000));
    let gutter_width = if node.show_line_numbers {
        line_number_width(total_count)
    } else {
        12.0
    };
    let content_width = gutter_width + max_columns as f32 * 8.5 + 24.0;

    let vertical_scroll = component.collection.scroll_handle.clone();
    let horizontal_scroll = component.horizontal_scroll_handle.clone();
    let focus_handle = component.collection.focus_handle.clone();
    let lines = Arc::new(lines);
    let theme = context.cx.theme();
    let visible = VisibleCode {
        id: node.id.clone(),
        lines: lines.clone(),
        offset,
        total_count,
        overscan,
        selected: node.selected.clone(),
        change_event: node.change.clone(),
        range_event: node.range.clone(),
        mode: node.mode.clone().unwrap_or_else(|| "plain".to_string()),
        show_line_numbers: node.show_line_numbers,
        tab_width,
        item_height: (node.item_height as f32).max(1.0),
        dark: theme.is_dark(),
        background: theme.background,
        foreground: theme.foreground,
        muted_foreground: theme.muted_foreground,
        selected_background: theme.primary,
        selected_foreground: theme.primary_foreground,
        mono_font_family: theme.mono_font_family.clone(),
        mono_font_size: theme.mono_font_size,
    };
    let processor = context.cx.processor(move |root, range, window, cx| {
        render_visible_lines(root, &visible, range, window, cx)
    });

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = node.change.clone();
    let copy_event = node.click.clone();
    let key_lines = keys.clone();
    let key_scroll = vertical_scroll.clone();
    let selected_position = selected_index
        .and_then(|selected_index| keys.iter().position(|key| key.index == selected_index));
    let disabled = node.disabled;
    let code_id = node.id.clone();

    let content = gpui::div()
        .w(gpui::px(content_width))
        .min_w_full()
        .h_full()
        .child(
            uniform_list(
                format!("gpui-elixir-code-viewer-list-{window_id}-{code_id}"),
                total_count,
                processor,
            )
            .track_scroll(&vertical_scroll)
            .size_full(),
        );
    let viewport = gpui::div()
        .id(format!(
            "gpui-elixir-code-viewer-horizontal-{window_id}-{code_id}"
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

    apply_generated_render_styles(gpui::div(), node.style)
        .id(code_id)
        .role(Role::ListBox)
        .aria_label(node.label.unwrap_or_else(|| "Code viewer".to_string()))
        .track_focus(&focus_handle.tab_stop(!disabled))
        .on_key_down(move |event, window, cx| {
            if disabled {
                return;
            }
            let key = event.keystroke.key.as_str();
            if key == "c" && event.keystroke.modifiers.secondary() {
                if let Some(position) = selected_position {
                    use gpui::ClipboardItem;
                    cx.write_to_clipboard(ClipboardItem::new_string(
                        key_lines[position].text.clone(),
                    ));
                    if let Some(copy_event) = copy_event.as_ref() {
                        let _ = crate::push_event(
                            &runtime,
                            crate::NativeEvent::Click {
                                window_id,
                                event: copy_event.clone(),
                            },
                        );
                    }
                    cx.stop_propagation();
                }
                return;
            }

            let Some(position) = key_target(key, &key_lines, selected_position, total_count) else {
                return;
            };
            let line = &key_lines[position];
            super::uniform_collection::emit_change(
                &runtime,
                window_id,
                change_event.as_deref(),
                &line.id,
            );
            key_scroll.scroll_to_item(line.index, gpui::ScrollStrategy::Nearest);
            window.refresh();
            cx.stop_propagation();
        })
        .child(viewport)
        .into_any_element()
}

#[cfg(feature = "components")]
fn render_visible_lines(
    root: &mut crate::ElixirRoot,
    code: &VisibleCode,
    range: Range<usize>,
    window: &mut gpui::Window,
    cx: &mut gpui::Context<'_, crate::ElixirRoot>,
) -> Vec<gpui::AnyElement> {
    use gpui::{IntoElement, Styled};

    let runtime = root.runtime.clone();
    let window_id = root.window_id;
    let Some(component) = root.components.code_viewer_mut(&code.id) else {
        return Vec::new();
    };
    let requested_range = range.start.saturating_sub(code.overscan)
        ..range
            .end
            .saturating_add(code.overscan)
            .min(code.total_count);
    super::uniform_collection::schedule_range(
        &mut component.collection,
        super::uniform_collection::CollectionKind::CodeViewer,
        &code.id,
        requested_range,
        code.range_event.as_deref(),
        &runtime,
        window_id,
        window,
        cx,
    );

    range
        .map(|index| {
            let line = index
                .checked_sub(code.offset)
                .and_then(|local_index| code.lines.get(local_index))
                .cloned();
            let Some(line) = line else {
                return gpui::div()
                    .h(gpui::px(code.item_height))
                    .w_full()
                    .into_any_element();
            };
            render_loaded_line(
                line,
                index,
                code,
                &runtime,
                window_id,
                &component.collection.focus_handle,
            )
        })
        .collect()
}

#[cfg(feature = "components")]
fn render_loaded_line(
    line: CodeLine,
    index: usize,
    code: &VisibleCode,
    runtime: &crate::SharedRuntime,
    window_id: u64,
    focus_handle: &gpui::FocusHandle,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{
        InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };

    let selected = code.selected.as_deref() == Some(line.id.as_str());
    let background = line_background(code, &line.kind, selected);
    let text_color = line_text_color(code, &line.kind, selected);
    let gutter_width = if code.show_line_numbers {
        line_number_width(code.total_count)
    } else {
        12.0
    };
    let expanded = expand_tabs(&line.text, code.tab_width);
    let accessibility_label = match line.number {
        Some(number) => format!("Line {number}: {expanded}"),
        None => expanded.clone(),
    };
    let event_name = code.change_event.clone();
    let event_id = line.id.clone();
    let item_runtime = runtime.clone();
    let item_focus = focus_handle.clone();

    let gutter = gpui::div()
        .w(gpui::px(gutter_width))
        .pr(gpui::px(12.0))
        .text_color(code.muted_foreground)
        .child(if code.show_line_numbers {
            line.number
                .map(|number| number.to_string())
                .unwrap_or_default()
        } else {
            String::new()
        });
    let text = gpui::div()
        .whitespace_nowrap()
        .font_family(code.mono_font_family.clone())
        .text_size(code.mono_font_size)
        .text_color(text_color)
        .child(expanded);
    let mut element = apply_generated_render_styles(gpui::div().bg(background), line.style)
        .h(gpui::px(code.item_height))
        .w_full()
        .id(format!(
            "gpui-elixir-code-line-{window_id}-{}-{}",
            code.id, line.id
        ))
        .role(Role::ListBoxOption)
        .aria_label(accessibility_label)
        .aria_position_in_set(index.saturating_add(1))
        .aria_size_of_set(code.total_count)
        .aria_selected(selected)
        .flex()
        .items_center()
        .children([gutter, text]);
    if selected {
        element = element.aria_active_descendant();
    }
    if !line.disabled {
        element =
            element
                .cursor(gpui::CursorStyle::PointingHand)
                .on_click(move |_event, window, cx| {
                    item_focus.focus(window, cx);
                    super::uniform_collection::emit_change(
                        &item_runtime,
                        window_id,
                        event_name.as_deref(),
                        &event_id,
                    );
                });
    }
    element.into_any_element()
}

#[cfg(feature = "components")]
fn key_target(
    key: &str,
    lines: &[CodeKey],
    selected: Option<usize>,
    total_count: usize,
) -> Option<usize> {
    match key {
        "down" => next_enabled(
            lines,
            selected.map_or(0, |position| position.saturating_add(1)),
        ),
        "up" => previous_enabled(lines, selected.unwrap_or(lines.len())),
        "pageup" => previous_enabled(lines, selected.unwrap_or(lines.len()).saturating_sub(10)),
        "pagedown" => next_enabled(
            lines,
            selected.map_or(0, |position| position.saturating_add(10).min(lines.len())),
        ),
        "home" => lines
            .iter()
            .position(|line| line.index == 0 && !line.disabled),
        "end" => lines
            .iter()
            .rposition(|line| line.index.saturating_add(1) == total_count && !line.disabled),
        "enter" | "space" => selected.filter(|position| !lines[*position].disabled),
        _other => None,
    }
}

#[cfg(feature = "components")]
fn next_enabled(lines: &[CodeKey], start: usize) -> Option<usize> {
    (start..lines.len()).find(|position| !lines[*position].disabled)
}

#[cfg(feature = "components")]
fn previous_enabled(lines: &[CodeKey], end: usize) -> Option<usize> {
    let end = end.min(lines.len());
    (0..end).rev().find(|position| !lines[*position].disabled)
}

#[cfg(feature = "components")]
fn expanded_columns(text: &str, tab_width: usize) -> usize {
    text.chars().fold(0, |column, character| {
        if character == '\t' {
            column + tab_width - column % tab_width
        } else {
            column + 1
        }
    })
}

#[cfg(feature = "components")]
fn expand_tabs(text: &str, tab_width: usize) -> String {
    let mut expanded = String::with_capacity(text.len());
    let mut column = 0;
    for character in text.chars() {
        if character == '\t' {
            let spaces = tab_width - column % tab_width;
            expanded.extend(std::iter::repeat_n(' ', spaces));
            column += spaces;
        } else {
            expanded.push(character);
            column += 1;
        }
    }
    expanded
}

#[cfg(feature = "components")]
fn line_number_width(total_count: usize) -> f32 {
    let digits = total_count.max(1).to_string().len();
    24.0 + digits as f32 * 8.5
}

#[cfg(feature = "components")]
fn line_background(code: &VisibleCode, kind: &str, selected: bool) -> gpui::Hsla {
    if selected {
        return code.selected_background;
    }
    if code.mode != "diff" {
        return code.background;
    }
    let color = match (code.dark, kind) {
        (true, "addition") => 0x0F3D2A,
        (true, "deletion") => 0x4A1D24,
        (true, "hunk") => 0x1E3A5F,
        (false, "addition") => 0xDCFCE7,
        (false, "deletion") => 0xFEE2E2,
        (false, "hunk") => 0xDBEAFE,
        _other => return code.background,
    };
    gpui::rgb(color).into()
}

#[cfg(feature = "components")]
fn line_text_color(code: &VisibleCode, kind: &str, selected: bool) -> gpui::Hsla {
    if selected {
        return code.selected_foreground;
    }
    if code.mode != "diff" {
        return code.foreground;
    }
    let color = match (code.dark, kind) {
        (true, "addition") => 0xA7F3D0,
        (true, "deletion") => 0xFECACA,
        (true, "hunk") => 0xBFDBFE,
        (false, "addition") => 0x166534,
        (false, "deletion") => 0x991B1B,
        (false, "hunk") => 0x1E40AF,
        _other => return code.foreground,
    };
    gpui::rgb(color).into()
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: CodeViewerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, node.children, context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_line(
    node: CodeLineComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, Some(node.text), Vec::new(), context)
}

#[cfg(feature = "components")]
pub(crate) fn render_line(
    node: CodeLineComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{IntoElement, ParentElement};

    apply_generated_render_styles(gpui::div(), node.style)
        .child(node.text)
        .into_any_element()
}

#[cfg(all(test, feature = "components"))]
mod tests {
    use super::*;

    #[test]
    fn tabs_expand_to_stable_columns() {
        assert_eq!(expand_tabs("a\tb", 4), "a   b");
        assert_eq!(expanded_columns("a\tb", 4), 5);
    }

    #[test]
    fn keyboard_navigation_skips_disabled_loaded_lines() {
        let lines = vec![
            CodeKey {
                id: "first".to_string(),
                text: "first".to_string(),
                disabled: false,
                index: 0,
            },
            CodeKey {
                id: "disabled".to_string(),
                text: "disabled".to_string(),
                disabled: true,
                index: 1,
            },
            CodeKey {
                id: "third".to_string(),
                text: "third".to_string(),
                disabled: false,
                index: 2,
            },
        ];

        assert_eq!(key_target("down", &lines, Some(0), 3), Some(2));
        assert_eq!(key_target("up", &lines, Some(2), 3), Some(0));
        assert_eq!(key_target("home", &lines, None, 3), Some(0));
        assert_eq!(key_target("end", &lines, None, 3), Some(2));
    }
}
