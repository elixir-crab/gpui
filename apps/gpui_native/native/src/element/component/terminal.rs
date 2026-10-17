//! Native mechanics for an application-owned terminal. No VT parser or PTY lives here.
use crate::element::{ElementNode, ElementRenderContext};
use crate::{
    gpui, push_event, EventValue, InputKind, NativeEvent, SharedRuntime, TerminalCellComponentNode,
    TerminalComponentNode, TerminalRowComponentNode,
};
use gpui::{
    actions, div, fill, point, px, size, App, AppContext, Bounds, ClipboardItem, Context,
    ElementInputHandler, EntityInputHandler, FocusHandle, InteractiveElement, IntoElement,
    KeyBinding, KeyDownEvent, Modifiers, MouseButton, ParentElement, Pixels, Render, ShapedLine,
    StatefulInteractiveElement, Styled, TextAlign, TextRun, UTF16Selection, Window,
};
use std::ops::Range;
use unicode_segmentation::UnicodeSegmentation;

actions!(gpui_terminal, [SendTab, SendBackTab]);

const KEY_CONTEXT: &str = "GPUITerminal";

/// Binds Tab and Shift-Tab inside a focused terminal, where they belong to the
/// remote shell (completion, reverse completion) rather than moving focus. The
/// terminal's context sits deeper than any window-level binding, so these win.
pub(crate) fn bind_terminal_keys(cx: &mut App) {
    cx.bind_keys([
        KeyBinding::new("tab", SendTab, Some(KEY_CONTEXT)),
        KeyBinding::new("shift-tab", SendBackTab, Some(KEY_CONTEXT)),
    ]);
}

const MAX_INPUT_BYTES: usize = 1_048_576;
const MAX_ROWS: usize = 10_000;
const MAX_TEXT_BYTES: usize = 8 * 1_048_576;
#[cfg(target_os = "macos")]
const DEFAULT_MONO_FAMILY: &str = "Menlo";
#[cfg(target_os = "windows")]
const DEFAULT_MONO_FAMILY: &str = "Consolas";
#[cfg(not(any(target_os = "macos", target_os = "windows")))]
const DEFAULT_MONO_FAMILY: &str = "DejaVu Sans Mono";

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
struct CellPoint {
    row: usize,
    column: usize,
}

#[derive(Clone, Debug)]
struct Run {
    text: String,
    columns: usize,
    color: Option<u32>,
    background: Option<u32>,
    bold: bool,
    italic: bool,
}

pub(crate) struct Terminal {
    node: TerminalComponentNode,
    rows: Vec<Vec<Run>>,
    runtime: SharedRuntime,
    window_id: u64,
    focus: FocusHandle,
    reset_request: u64,
    top: usize,
    tail: bool,
    selection: Option<(CellPoint, CellPoint)>,
    dragging: bool,
    marked: String,
    marked_selection: Range<usize>,
    bounds: Bounds<Pixels>,
    cell_width: f32,
    cell_height: f32,
    visible_rows: usize,
    last_size: Option<(usize, usize, u32, u32)>,
    last_range: Option<(usize, usize)>,
    scroll_remainder: f32,
}

fn decode_rows(node: &TerminalComponentNode) -> Option<Vec<Vec<Run>>> {
    if node.columns == 0 || node.columns > 512 || node.children.len() > MAX_ROWS {
        return None;
    }
    let mut bytes = 0usize;
    let mut rows = Vec::with_capacity(node.children.len());
    for row in &node.children {
        let ElementNode::TerminalRowComponent(row) = row else {
            return None;
        };
        let mut used = 0u64;
        let mut runs = Vec::with_capacity(row.children.len());
        for cell in &row.children {
            let ElementNode::TerminalCellComponent(cell) = cell else {
                return None;
            };
            bytes = bytes.checked_add(cell.text.len())?;
            used = used.checked_add(cell.columns)?;
            if bytes > MAX_TEXT_BYTES
                || cell.columns == 0
                || used > node.columns
                || cell.text.chars().any(char::is_control)
                || !(cell.text.is_ascii() && cell.text.len() == cell.columns as usize
                    || cell.text.graphemes(true).count() == 1 && cell.columns <= 2)
            {
                return None;
            }
            runs.push(Run {
                text: cell.text.clone(),
                columns: cell.columns as usize,
                color: cell.style.color,
                background: cell.style.background,
                bold: cell.style.font_weight.as_deref() == Some("bold"),
                italic: cell.italic,
            });
        }
        rows.push(runs);
    }
    Some(rows)
}

impl Terminal {
    pub(crate) fn input_focused(&self, window: &Window) -> bool {
        !self.node.disabled && self.focus.is_focused(window)
    }

    fn new(
        node: TerminalComponentNode,
        runtime: SharedRuntime,
        window_id: u64,
        cx: &mut Context<Self>,
    ) -> Self {
        let rows = decode_rows(&node).unwrap_or_default();
        Self {
            node,
            rows,
            runtime,
            window_id,
            focus: cx.focus_handle(),
            reset_request: 0,
            top: 0,
            tail: true,
            selection: None,
            dragging: false,
            marked: String::new(),
            marked_selection: 0..0,
            bounds: Bounds::default(),
            cell_width: 8.0,
            cell_height: 20.0,
            visible_rows: 1,
            last_size: None,
            last_range: None,
            scroll_remainder: 0.0,
        }
    }

    fn reconcile(
        &mut self,
        node: TerminalComponentNode,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) {
        if node.reset_request != self.reset_request || node.columns != self.node.columns {
            self.reset_request = node.reset_request;
            self.selection = None;
            self.marked.clear();
            self.marked_selection = 0..0;
            self.tail = true;
            self.scroll_remainder = 0.0;
        }
        self.rows = decode_rows(&node).unwrap_or_default();
        self.node = node;
        self.clamp_scroll();
    }

    fn clamp_scroll(&mut self) {
        let end = self.rows.len().saturating_sub(self.visible_rows);
        self.top = if self.tail { end } else { self.top.min(end) };
    }

    fn emit_text(&mut self, kind: InputKind, event: Option<String>, text: String) {
        if self.node.disabled || text.is_empty() || text.len() > MAX_INPUT_BYTES {
            return;
        }
        self.tail = true;
        self.selection = None;
        self.clamp_scroll();
        if let Some(event) = event {
            let _ = push_event(
                &self.runtime,
                NativeEvent::Input {
                    kind,
                    window_id: self.window_id,
                    event,
                    value: Some(EventValue::String(text)),
                },
            );
        }
    }

    fn key_down(&mut self, event: &KeyDownEvent, window: &mut Window, cx: &mut Context<Self>) {
        if self.node.disabled {
            return;
        }
        let key = event.keystroke.key.as_str();
        if key.is_empty() {
            return;
        }
        let mods = event.keystroke.modifiers;
        if !self.marked.is_empty() && !mods.control && !mods.alt && !mods.platform {
            return;
        }
        // Platform shortcuts remain application commands, not remote input.
        if mods.platform
            || (cfg!(not(target_os = "macos"))
                && mods.control
                && mods.shift
                && matches!(key, "c" | "v"))
        {
            match key {
                "c" => {
                    if let Some(text) = self.selected_text() {
                        cx.write_to_clipboard(ClipboardItem::new_string(text));
                    }
                }
                "v" => {
                    if let Some(text) = cx.read_from_clipboard().and_then(|item| item.text()) {
                        if text.len() > MAX_INPUT_BYTES {
                            window.play_system_bell();
                            return;
                        }
                        self.emit_text(InputKind::Paste, self.node.paste.clone(), text);
                    }
                }
                "a" => {
                    self.selection = Some((
                        CellPoint { row: 0, column: 0 },
                        CellPoint {
                            row: self.rows.len().saturating_sub(1),
                            column: self.node.columns as usize,
                        },
                    ));
                }
                _ => return,
            }
            cx.stop_propagation();
            cx.notify();
            return;
        }
        if mods.shift && matches!(key, "pageup" | "pagedown" | "home" | "end") {
            let page = self.visible_rows.saturating_sub(1).max(1);
            self.top = match key {
                "pageup" => self.top.saturating_sub(page),
                "pagedown" => self.top.saturating_add(page),
                "home" => 0,
                _ => self.rows.len(),
            };
            self.tail = key == "end";
            self.clamp_scroll();
            cx.stop_propagation();
            cx.notify();
            return;
        }
        // Ordinary Unicode text is committed through EntityInputHandler, including
        // IME. Never emit both the printable key and its committed text.
        if !mods.control && !mods.alt && (key.chars().count() == 1 || key == "space") {
            return;
        }
        self.send_keystroke(key, mods, event.is_held, cx);
        cx.stop_propagation();
    }

    fn send_keystroke(&mut self, key: &str, mods: Modifiers, repeat: bool, cx: &mut Context<Self>) {
        self.tail = true;
        self.selection = None;
        self.clamp_scroll();
        if let Some(event_name) = &self.node.keystroke {
            let _ = push_event(
                &self.runtime,
                NativeEvent::Keystroke {
                    window_id: self.window_id,
                    event: event_name.clone(),
                    value: crate::event::KeyStroke {
                        key: key.to_string(),
                        control: mods.control,
                        alt: mods.alt,
                        shift: mods.shift,
                        platform: mods.platform,
                        repeat,
                    },
                },
            );
        }
        cx.notify();
    }

    // A disabled terminal leaves Tab to the window, which moves focus on.
    fn send_tab(&mut self, _: &SendTab, _window: &mut Window, cx: &mut Context<Self>) {
        if self.node.disabled {
            cx.propagate();
            return;
        }
        self.send_keystroke("tab", Modifiers::default(), false, cx);
    }

    fn send_back_tab(&mut self, _: &SendBackTab, _window: &mut Window, cx: &mut Context<Self>) {
        if self.node.disabled {
            cx.propagate();
            return;
        }
        self.send_keystroke("tab", Modifiers::shift(), false, cx);
    }

    fn point(&self, position: gpui::Point<Pixels>) -> CellPoint {
        let row = ((f32::from(position.y - self.bounds.top()) / self.cell_height)
            .floor()
            .max(0.0) as usize)
            .saturating_add(self.top)
            .min(self.rows.len().saturating_sub(1));
        let column = (f32::from(position.x - self.bounds.left()) / self.cell_width)
            .round()
            .max(0.0) as usize;
        CellPoint {
            row,
            column: column.min(self.node.columns as usize),
        }
    }

    fn selected_text(&self) -> Option<String> {
        if self.rows.is_empty() {
            return None;
        }
        let (a, b) = self.selection?;
        if a == b {
            return None;
        }
        let (start, end) = (a.min(b), a.max(b));
        let mut lines = Vec::new();
        for row in start.row..=end.row.min(self.rows.len().saturating_sub(1)) {
            let left = if row == start.row { start.column } else { 0 };
            let right = if row == end.row {
                end.column
            } else {
                self.node.columns as usize
            };
            lines.push(
                copy_row(&self.rows[row], left, right)
                    .trim_end()
                    .to_string(),
            );
        }
        Some(lines.join("\n"))
    }

    fn prepare(
        &mut self,
        bounds: Bounds<Pixels>,
        window: &mut Window,
    ) -> Vec<(gpui::Point<Pixels>, ShapedLine, usize)> {
        self.bounds = bounds;
        let family = if self.node.font_family.is_empty() {
            DEFAULT_MONO_FAMILY
        } else {
            &self.node.font_family
        };
        let mut font = gpui::font(family.to_string());
        font.features = gpui::FontFeatures::disable_ligatures();
        let font_size = px((self.node.font_size as f32).clamp(6.0, 96.0));
        let foreground: gpui::Hsla = gpui::rgba(self.node.style.color.unwrap_or(0xe5e5e5ff)).into();
        let sample = window.text_system().shape_line(
            "M".into(),
            font_size,
            &[TextRun {
                len: 1,
                font: font.clone(),
                color: foreground,
                background_color: None,
                underline: None,
                strikethrough: None,
            }],
            None,
        );
        self.cell_width = f32::from(sample.width).max(1.0);
        self.cell_height = (self.node.line_height as f32).clamp(f32::from(font_size), 128.0);
        let columns = (f32::from(bounds.size.width) / self.cell_width)
            .floor()
            .clamp(1.0, 512.0) as usize;
        self.visible_rows = (f32::from(bounds.size.height) / self.cell_height)
            .floor()
            .clamp(1.0, 256.0) as usize;
        self.clamp_scroll();
        let range = (
            self.top,
            (self.top + self.visible_rows).min(self.rows.len()),
        );
        if self.last_range != Some(range) {
            self.last_range = Some(range);
            if let Some(event) = &self.node.range {
                let _ = push_event(
                    &self.runtime,
                    NativeEvent::VirtualRange {
                        window_id: self.window_id,
                        event: event.clone(),
                        first: range.0 as u64,
                        last: range.1 as u64,
                    },
                );
            }
        }
        let key = (
            columns,
            self.visible_rows,
            self.cell_width.to_bits(),
            self.cell_height.to_bits(),
        );
        if bounds.size.width > px(0.0)
            && bounds.size.height > px(0.0)
            && self.last_size != Some(key)
        {
            self.last_size = Some(key);
            if let Some(event) = &self.node.resize {
                let _ = push_event(
                    &self.runtime,
                    NativeEvent::TerminalResize {
                        window_id: self.window_id,
                        event: event.clone(),
                        value: crate::event::TerminalSize {
                            columns: columns as u64,
                            rows: self.visible_rows as u64,
                            cell_width: self.cell_width as f64,
                            cell_height: self.cell_height as f64,
                        },
                    },
                );
            }
        }
        let mut shaped = Vec::new();
        for (visible_row, row) in self
            .rows
            .iter()
            .skip(self.top)
            .take(self.visible_rows)
            .enumerate()
        {
            let mut column = 0;
            for run in row {
                let mut run_font = font.clone();
                if run.bold {
                    run_font.weight = gpui::FontWeight::BOLD;
                }
                if run.italic {
                    run_font.style = gpui::FontStyle::Italic;
                }
                let graphemes = run.text.graphemes(true).collect::<Vec<_>>();
                let span = run.columns / graphemes.len().max(1);
                for grapheme in graphemes {
                    if grapheme == " " {
                        column += span;
                        continue;
                    }
                    let text = window.text_system().shape_line(
                        grapheme.to_string().into(),
                        font_size,
                        &[TextRun {
                            len: grapheme.len(),
                            font: run_font.clone(),
                            color: run
                                .color
                                .map(|c| gpui::rgba(c).into())
                                .unwrap_or(foreground),
                            background_color: None,
                            underline: None,
                            strikethrough: None,
                        }],
                        None,
                    );
                    shaped.push((
                        point(
                            bounds.left() + px(column as f32 * self.cell_width),
                            bounds.top() + px(visible_row as f32 * self.cell_height),
                        ),
                        text,
                        span,
                    ));
                    column += span;
                }
            }
        }
        if !self.marked.is_empty() {
            let text = window.text_system().shape_line(
                self.marked.clone().into(),
                font_size,
                &[TextRun {
                    len: self.marked.len(),
                    font,
                    color: foreground,
                    background_color: None,
                    underline: Some(gpui::UnderlineStyle {
                        color: Some(foreground),
                        thickness: px(1.0),
                        wavy: false,
                    }),
                    strikethrough: None,
                }],
                None,
            );
            shaped.push((
                point(
                    bounds.left() + px(self.node.cursor_column as f32 * self.cell_width),
                    bounds.top()
                        + px(self.node.cursor_row.saturating_sub(self.top as u64) as f32
                            * self.cell_height),
                ),
                text,
                self.node.columns as usize,
            ));
        }
        shaped
    }

    fn paint(
        &self,
        shaped: Vec<(gpui::Point<Pixels>, ShapedLine, usize)>,
        window: &mut Window,
        cx: &mut App,
    ) {
        let selection = self.selection.map(|(a, b)| (a.min(b), a.max(b)));
        for (visible_row, row) in self
            .rows
            .iter()
            .skip(self.top)
            .take(self.visible_rows)
            .enumerate()
        {
            let mut column = 0;
            for run in row {
                if let Some(color) = run.background {
                    window.paint_quad(fill(
                        Bounds::new(
                            point(
                                self.bounds.left() + px(column as f32 * self.cell_width),
                                self.bounds.top() + px(visible_row as f32 * self.cell_height),
                            ),
                            size(
                                px(run.columns as f32 * self.cell_width),
                                px(self.cell_height),
                            ),
                        ),
                        gpui::rgba(color),
                    ));
                }
                column += run.columns;
            }
            if let Some((start, end)) = selection {
                let logical_row = self.top + visible_row;
                if (start.row..=end.row).contains(&logical_row) {
                    let left = if start.row == logical_row {
                        start.column
                    } else {
                        0
                    };
                    let right = if end.row == logical_row {
                        end.column
                    } else {
                        self.node.columns as usize
                    };
                    window.paint_quad(fill(
                        Bounds::new(
                            point(
                                self.bounds.left() + px(left as f32 * self.cell_width),
                                self.bounds.top() + px(visible_row as f32 * self.cell_height),
                            ),
                            size(
                                px(right.saturating_sub(left) as f32 * self.cell_width),
                                px(self.cell_height),
                            ),
                        ),
                        gpui::Hsla::from(gpui::rgba(self.node.style.color.unwrap_or(0xe5e5e5ff)))
                            .opacity(0.25),
                    ));
                }
            }
        }
        for (origin, line, columns) in shaped {
            window.with_content_mask(
                Some(gpui::ContentMask {
                    bounds: Bounds::new(
                        origin,
                        size(px(columns as f32 * self.cell_width), px(self.cell_height)),
                    ),
                }),
                |window| {
                    let _ = line.paint(
                        origin,
                        px(self.cell_height),
                        TextAlign::Left,
                        None,
                        window,
                        cx,
                    );
                },
            );
        }
        let row = self.node.cursor_row as usize;
        if self.node.cursor_visible
            && row >= self.top
            && row < self.top + self.visible_rows
            && self.focus.is_focused(window)
        {
            window.paint_quad(fill(
                Bounds::new(
                    point(
                        self.bounds.left() + px(self.node.cursor_column as f32 * self.cell_width),
                        self.bounds.top()
                            + px(
                                (row - self.top) as f32 * self.cell_height + self.cell_height - 2.0,
                            ),
                    ),
                    size(px(self.cell_width), px(2.0)),
                ),
                gpui::rgba(self.node.style.color.unwrap_or(0xe5e5e5ff)),
            ));
        }
    }
}

fn copy_row(runs: &[Run], left: usize, right: usize) -> String {
    let mut column = 0;
    let mut text = String::new();
    for run in runs {
        let graphemes = run.text.graphemes(true).collect::<Vec<_>>();
        let width = run.columns / graphemes.len().max(1);
        for grapheme in graphemes {
            if column < right && column + width > left {
                text.push_str(grapheme);
            }
            column += width;
        }
    }
    text
}

impl Render for Terminal {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let prepare = cx.entity();
        let paint = cx.entity();
        div()
            .size_full()
            .relative()
            .overflow_hidden()
            .id("terminal-input")
            .key_context(KEY_CONTEXT)
            .track_focus(&self.focus)
            .on_key_down(cx.listener(Self::key_down))
            .on_action(cx.listener(Self::send_tab))
            .on_action(cx.listener(Self::send_back_tab))
            .on_mouse_down(
                MouseButton::Left,
                cx.listener(|this, event: &gpui::MouseDownEvent, window, cx| {
                    this.focus.focus(window, cx);
                    let point = this.point(event.position);
                    this.selection = Some((point, point));
                    this.dragging = true;
                    cx.notify();
                }),
            )
            .on_mouse_move(
                cx.listener(|this, event: &gpui::MouseMoveEvent, _window, cx| {
                    if event.pressed_button != Some(MouseButton::Left) {
                        this.dragging = false;
                    }
                    if this.dragging {
                        let point = this.point(event.position);
                        if let Some((anchor, _)) = this.selection {
                            this.selection = Some((anchor, point));
                        }
                        cx.notify();
                    }
                }),
            )
            .on_mouse_up(
                MouseButton::Left,
                cx.listener(|this, _event, _window, _cx| this.dragging = false),
            )
            .on_scroll_wheel(
                cx.listener(|this, event: &gpui::ScrollWheelEvent, _window, cx| {
                    let delta = f32::from(event.delta.pixel_delta(px(this.cell_height)).y);
                    this.scroll_remainder -= delta / this.cell_height;
                    let rows = this.scroll_remainder.trunc() as isize;
                    this.scroll_remainder -= rows as f32;
                    this.top = this.top.saturating_add_signed(rows);
                    this.tail = this.top >= this.rows.len().saturating_sub(this.visible_rows);
                    this.clamp_scroll();
                    cx.stop_propagation();
                    cx.notify();
                }),
            )
            .child(
                gpui::canvas(
                    move |bounds, window, cx| {
                        prepare.update(cx, |terminal, _| terminal.prepare(bounds, window))
                    },
                    move |bounds, shaped, window, cx| {
                        paint.update(cx, |terminal, cx| {
                            if !terminal.node.disabled {
                                window.handle_input(
                                    &terminal.focus,
                                    ElementInputHandler::new(bounds, paint.clone()),
                                    cx,
                                );
                            }
                            terminal.paint(shaped, window, cx);
                        });
                    },
                )
                .size_full(),
            )
    }
}

// A terminal has no locally editable command line. Only an uncommitted IME
// composition is retained; commit emits text once and leaves remote editing to
// the PTY. Clipboard paste takes the separate path above and keeps newlines.
impl EntityInputHandler for Terminal {
    fn text_for_range(
        &mut self,
        range: Range<usize>,
        adjusted: &mut Option<Range<usize>>,
        _: &mut Window,
        _: &mut Context<Self>,
    ) -> Option<String> {
        let (bytes, utf16) = composition_range(&self.marked, range);
        *adjusted = Some(utf16);
        Some(self.marked[bytes].to_string())
    }
    fn selected_text_range(
        &mut self,
        _: bool,
        _: &mut Window,
        _: &mut Context<Self>,
    ) -> Option<UTF16Selection> {
        Some(UTF16Selection {
            range: self.marked_selection.clone(),
            reversed: false,
        })
    }
    fn marked_text_range(&self, _: &mut Window, _: &mut Context<Self>) -> Option<Range<usize>> {
        (!self.marked.is_empty()).then(|| 0..self.marked.encode_utf16().count())
    }
    fn unmark_text(&mut self, _: &mut Window, cx: &mut Context<Self>) {
        self.marked.clear();
        self.marked_selection = 0..0;
        cx.notify();
    }
    fn replace_text_in_range(
        &mut self,
        _: Option<Range<usize>>,
        text: &str,
        _: &mut Window,
        cx: &mut Context<Self>,
    ) {
        self.marked.clear();
        self.marked_selection = 0..0;
        self.emit_text(InputKind::Text, self.node.text.clone(), text.to_string());
        cx.notify();
    }
    fn replace_and_mark_text_in_range(
        &mut self,
        _: Option<Range<usize>>,
        text: &str,
        selection: Option<Range<usize>>,
        _: &mut Window,
        cx: &mut Context<Self>,
    ) {
        if text.len() <= MAX_INPUT_BYTES {
            self.marked = text.to_string();
            let end = text.encode_utf16().count();
            self.marked_selection = composition_range(text, selection.unwrap_or(end..end)).1;
        }
        cx.notify();
    }
    fn bounds_for_range(
        &mut self,
        _: Range<usize>,
        _: Bounds<Pixels>,
        _: &mut Window,
        _: &mut Context<Self>,
    ) -> Option<Bounds<Pixels>> {
        Some(Bounds::new(
            point(
                self.bounds.left() + px(self.node.cursor_column as f32 * self.cell_width),
                self.bounds.top()
                    + px(self.node.cursor_row.saturating_sub(self.top as u64) as f32
                        * self.cell_height),
            ),
            size(px(self.cell_width), px(self.cell_height)),
        ))
    }
    fn character_index_for_point(
        &mut self,
        _: gpui::Point<Pixels>,
        _: &mut Window,
        _: &mut Context<Self>,
    ) -> Option<usize> {
        Some(0)
    }
}

pub(crate) fn render(
    node: TerminalComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    let id = format!("terminal-{}-{}", context.id_namespace, node.id);
    context.active_input_ids.insert(id.clone());
    let terminal = if let Some(terminal) = context.terminal_entities.get(&id).cloned() {
        terminal.update(context.cx, |terminal, cx| {
            terminal.reconcile(node.clone(), context.window, cx)
        });
        terminal
    } else {
        let terminal = context
            .cx
            .new(|cx| Terminal::new(node.clone(), context.runtime.clone(), context.window_id, cx));
        terminal.update(context.cx, |terminal, cx| {
            terminal.reconcile(node.clone(), context.window, cx)
        });
        context.terminal_entities.insert(id, terminal.clone());
        terminal
    };
    if let Ok(mut handles) = context.runtime.focus_handles.lock() {
        handles.insert(
            (context.window_id, node.id.clone()),
            terminal.read(context.cx).focus.clone(),
        );
    }
    let focus = terminal.read(context.cx).focus.clone();
    crate::element::request_native_focus(
        &focus,
        node.id.clone(),
        if node.disabled { 0 } else { node.focus_request },
        context.runtime.clone(),
        context.window_id,
        context,
    );
    crate::element::apply_generated_render_styles(div().size_full(), node.style)
        .id(node.id.clone())
        .debug_selector(|| node.id)
        .role(gpui::Role::TextInput)
        .aria_label(node.label)
        .child(terminal)
        .into_any_element()
}

pub(crate) fn render_row(
    _node: TerminalRowComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    div().into_any_element()
}
pub(crate) fn render_cell(
    _node: TerminalCellComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    div().into_any_element()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn copied_selection_has_no_cursor_artifact_and_respects_wide_cells() {
        let runs = vec![
            Run {
                text: "ab".into(),
                columns: 2,
                color: None,
                background: None,
                bold: false,
                italic: false,
            },
            Run {
                text: "界".into(),
                columns: 2,
                color: None,
                background: None,
                bold: false,
                italic: false,
            },
            Run {
                text: "cd".into(),
                columns: 2,
                color: None,
                background: None,
                bold: false,
                italic: false,
            },
        ];
        assert_eq!(copy_row(&runs, 1, 5), "b界c");
        assert_eq!(copy_row(&runs, 3, 4), "界");
    }

    #[test]
    fn composition_ranges_never_split_surrogate_pairs() {
        assert_eq!(composition_range("a😀b", 1..3), (1..5, 1..3));
        assert_eq!(composition_range("a😀b", 2..3), (1..5, 1..3));
        assert_eq!(composition_range("a😀b", 99..100), (6..6, 4..4));
    }
}

fn composition_range(text: &str, requested: Range<usize>) -> (Range<usize>, Range<usize>) {
    let mut offsets = text
        .char_indices()
        .scan(0usize, |utf16, (byte, ch)| {
            let point = (byte, *utf16);
            *utf16 += ch.len_utf16();
            Some(point)
        })
        .collect::<Vec<_>>();
    offsets.push((text.len(), text.encode_utf16().count()));
    let start = offsets
        .iter()
        .rev()
        .find(|(_, n)| *n <= requested.start)
        .copied()
        .unwrap_or((0, 0));
    let end = offsets
        .iter()
        .find(|(_, n)| *n >= requested.end.max(requested.start))
        .copied()
        .unwrap_or(*offsets.last().unwrap());
    (start.0..end.0, start.1..end.1)
}
