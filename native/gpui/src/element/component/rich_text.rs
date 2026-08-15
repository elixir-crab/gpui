use crate::element::ElementRenderContext;
#[cfg(feature = "components")]
use crate::RichTextRunNode;
#[cfg(any(feature = "components", test))]
use crate::TextPosition;
use crate::{gpui, RichTextComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
use std::ops::Range;
#[cfg(feature = "components")]
use std::sync::{Arc, Mutex};

#[cfg(feature = "components")]
pub(crate) struct ComponentRichText {
    selection: Arc<Mutex<RichSelection>>,
    focus_handle: gpui::FocusHandle,
    text: String,
}

#[cfg(feature = "components")]
impl ComponentRichText {
    fn new(cx: &mut gpui::Context<'_, crate::ElixirRoot>) -> Self {
        Self {
            selection: Arc::new(Mutex::new(RichSelection::default())),
            focus_handle: cx.focus_handle(),
            text: String::new(),
        }
    }
}

#[cfg(feature = "components")]
#[derive(Clone, Debug, Default)]
struct RichSelection {
    anchor: usize,
    head: usize,
    dragging: bool,
}

#[cfg(feature = "components")]
impl RichSelection {
    fn range(&self) -> Range<usize> {
        self.anchor.min(self.head)..self.anchor.max(self.head)
    }

    fn clear(&mut self) {
        self.anchor = 0;
        self.head = 0;
        self.dragging = false;
    }
}

#[cfg(feature = "components")]
#[derive(Clone, Debug)]
struct NativeRichRun {
    range: Range<usize>,
    source: RichTextRunNode,
}

#[cfg(feature = "components")]
struct RichTextElement {
    id: String,
    label: String,
    text: gpui::SharedString,
    runs: Vec<NativeRichRun>,
    selectable: bool,
    selection: Arc<Mutex<RichSelection>>,
    link_event: Option<String>,
    runtime: crate::SharedRuntime,
    window_id: u64,
    styled_text: gpui::StyledText,
}

#[cfg(feature = "components")]
impl RichTextElement {
    fn new(
        node: &RichTextComponentNode,
        selection: Arc<Mutex<RichSelection>>,
        runtime: crate::SharedRuntime,
        window_id: u64,
    ) -> Self {
        let text: gpui::SharedString = node.text.clone().into();
        let runs = native_runs(&node.text, &node.runs);
        Self {
            id: node.id.clone(),
            label: node.label.clone().unwrap_or_else(|| "Text".to_string()),
            text: text.clone(),
            runs,
            selectable: node.selectable,
            selection,
            link_event: node.link.clone(),
            runtime,
            window_id,
            styled_text: gpui::StyledText::new(text),
        }
    }

    fn selected_text(&self) -> Option<String> {
        let range = self.selection.lock().ok()?.range();
        (!range.is_empty())
            .then(|| self.text.get(range).map(str::to_string))
            .flatten()
    }

    fn link_at(&self, index: usize) -> Option<&str> {
        self.runs
            .iter()
            .find(|run| run.range.contains(&index))
            .and_then(|run| run.source.link.as_deref())
    }
}

#[cfg(feature = "components")]
impl gpui::IntoElement for RichTextElement {
    type Element = Self;

    fn into_element(self) -> Self::Element {
        self
    }
}

#[cfg(feature = "components")]
impl gpui::Element for RichTextElement {
    type RequestLayoutState = ();
    type PrepaintState = gpui::Hitbox;

    fn id(&self) -> Option<gpui::ElementId> {
        Some(gpui::ElementId::Name(self.id.clone().into()))
    }

    fn source_location(&self) -> Option<&'static std::panic::Location<'static>> {
        None
    }

    fn request_layout(
        &mut self,
        global_id: Option<&gpui::GlobalElementId>,
        inspector_id: Option<&gpui::InspectorElementId>,
        window: &mut gpui::Window,
        cx: &mut gpui::App,
    ) -> (gpui::LayoutId, Self::RequestLayoutState) {
        let shaped_runs = shaped_runs(&window.text_style(), self.text.len(), &self.runs);
        self.styled_text = gpui::StyledText::new(self.text.clone()).with_runs(shaped_runs);
        let (layout_id, _) = self
            .styled_text
            .request_layout(global_id, inspector_id, window, cx);
        (layout_id, ())
    }

    fn prepaint(
        &mut self,
        global_id: Option<&gpui::GlobalElementId>,
        inspector_id: Option<&gpui::InspectorElementId>,
        bounds: gpui::Bounds<gpui::Pixels>,
        _state: &mut Self::RequestLayoutState,
        window: &mut gpui::Window,
        cx: &mut gpui::App,
    ) -> Self::PrepaintState {
        self.styled_text
            .prepaint(global_id, inspector_id, bounds, &mut (), window, cx);
        window.insert_hitbox(bounds, gpui::HitboxBehavior::Normal)
    }

    fn paint(
        &mut self,
        global_id: Option<&gpui::GlobalElementId>,
        _inspector_id: Option<&gpui::InspectorElementId>,
        bounds: gpui::Bounds<gpui::Pixels>,
        _state: &mut Self::RequestLayoutState,
        hitbox: &mut Self::PrepaintState,
        window: &mut gpui::Window,
        cx: &mut gpui::App,
    ) {
        let layout = self.styled_text.layout().clone();
        if let Ok(selection) = self.selection.lock() {
            paint_selection(&selection.range(), &layout, bounds, window);
        }
        self.styled_text
            .paint(global_id, None, bounds, &mut (), &mut (), window, cx);

        if self.selectable {
            window.set_cursor_style(gpui::CursorStyle::IBeam, hitbox);
        }
        if let Ok(index) = layout.index_for_position(window.mouse_position()) {
            if self.link_at(index).is_some() {
                window.set_cursor_style(gpui::CursorStyle::PointingHand, hitbox);
            }
        }

        if self.selectable {
            window.on_mouse_event({
                let hitbox = hitbox.clone();
                let layout = layout.clone();
                let selection = self.selection.clone();
                move |event: &gpui::MouseDownEvent, phase, window, _cx| {
                    if !phase.bubble()
                        || event.button != gpui::MouseButton::Left
                        || !hitbox.is_hovered(window)
                    {
                        return;
                    }
                    let index = closest_index(&layout, event.position);
                    if let Ok(mut selection) = selection.lock() {
                        selection.anchor = index;
                        selection.head = index;
                        selection.dragging = true;
                    }
                }
            });
            window.on_mouse_event({
                let layout = layout.clone();
                let selection = self.selection.clone();
                move |event: &gpui::MouseMoveEvent, phase, window, cx| {
                    if !phase.bubble() || event.pressed_button != Some(gpui::MouseButton::Left) {
                        return;
                    }
                    if let Ok(mut selection) = selection.lock() {
                        if selection.dragging {
                            selection.head = closest_index(&layout, event.position);
                            cx.notify(window.current_view());
                        }
                    }
                }
            });
        }

        window.on_mouse_event({
            let hitbox = hitbox.clone();
            let layout = layout.clone();
            let selection = self.selection.clone();
            let runs = self.runs.clone();
            let event_name = self.link_event.clone();
            let runtime = self.runtime.clone();
            let window_id = self.window_id;
            move |event: &gpui::MouseUpEvent, phase, window, cx| {
                if !phase.bubble()
                    || event.button != gpui::MouseButton::Left
                    || !hitbox.is_hovered(window)
                {
                    return;
                }
                let selected = selection
                    .lock()
                    .map(|mut selection| {
                        selection.dragging = false;
                        !selection.range().is_empty()
                    })
                    .unwrap_or(false);
                if selected {
                    cx.stop_propagation();
                    return;
                }
                let index = closest_index(&layout, event.position);
                let link = runs
                    .iter()
                    .find(|run| run.range.contains(&index))
                    .and_then(|run| run.source.link.as_deref());
                if let (Some(link), Some(event_name)) = (link, event_name.as_deref()) {
                    let _ = crate::push_event(
                        &runtime,
                        crate::NativeEvent::Input {
                            kind: crate::InputKind::Link,
                            window_id,
                            event: event_name.to_string(),
                            value: Some(crate::EventValue::String(link.to_string())),
                        },
                    );
                    cx.stop_propagation();
                }
            }
        });
    }

    fn a11y_role(&self) -> Option<gpui::Role> {
        Some(gpui::Role::Document)
    }

    fn write_a11y_info(&self, node: &mut gpui::accesskit::Node) {
        node.set_label(self.label.clone());
        node.set_value(self.text.to_string());
    }

    fn a11y_synthetic_children(
        &mut self,
        _prepaint: &mut Self::PrepaintState,
        builder: &mut gpui::A11ySubtreeBuilder,
    ) {
        let mut run = gpui::accesskit::Node::new(gpui::Role::TextRun);
        run.set_value(self.text.to_string());
        run.set_character_lengths(
            self.text
                .chars()
                .map(|character| character.len_utf8() as u8)
                .collect::<Vec<_>>(),
        );
        let run_id = builder.synthetic_node_id(0);
        builder.push_child(run_id, run);

        if let Ok(selection) = self.selection.lock() {
            let range = selection.range();
            builder
                .parent_node()
                .set_text_selection(gpui::accesskit::TextSelection {
                    anchor: gpui::accesskit::TextPosition {
                        node: run_id,
                        character_index: byte_to_character_index(&self.text, range.start),
                    },
                    focus: gpui::accesskit::TextPosition {
                        node: run_id,
                        character_index: byte_to_character_index(&self.text, range.end),
                    },
                });
        }
    }
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: RichTextComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::element::apply_generated_render_styles;
    use gpui::{InteractiveElement, IntoElement, ParentElement};

    if context.components.rich_text_mut(&node.id).is_none() {
        let component = ComponentRichText::new(context.cx);
        context.components.insert_rich_text(&node.id, component);
    }
    let component = context
        .components
        .rich_text_mut(&node.id)
        .expect("rich text component must exist after insertion");
    if let Ok(mut selection) = component.selection.lock() {
        if !node.selectable {
            selection.clear();
        } else {
            reconcile_selection(&mut selection, &component.text, &node.text);
        }
    }
    component.text.clone_from(&node.text);
    let selection = component.selection.clone();
    let focus_handle = component.focus_handle.clone();
    let text_element = RichTextElement::new(
        &node,
        selection.clone(),
        context.runtime.clone(),
        context.window_id,
    );
    let copy_element =
        RichTextElement::new(&node, selection, context.runtime.clone(), context.window_id);

    let focus_for_pointer = focus_handle.clone();

    apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .track_focus(&focus_handle)
        .on_mouse_down(gpui::MouseButton::Left, move |_event, window, cx| {
            focus_for_pointer.focus(window, cx);
        })
        .on_key_down(move |event, _window, cx| {
            let key = event.keystroke.key.as_str();
            if key == "c" && event.keystroke.modifiers.secondary() {
                if let Some(text) = copy_element.selected_text() {
                    cx.write_to_clipboard(gpui::ClipboardItem::new_string(text));
                    cx.stop_propagation();
                }
            }
        })
        .child(text_element)
        .into_any_element()
}

#[cfg(feature = "components")]
fn closest_index(layout: &gpui::TextLayout, position: gpui::Point<gpui::Pixels>) -> usize {
    match layout.index_for_position(position) {
        Ok(index) | Err(index) => index,
    }
}

#[cfg(feature = "components")]
fn clamp_selection(selection: &mut RichSelection, text: &str) {
    selection.anchor = clamp_byte_index(text, selection.anchor);
    selection.head = clamp_byte_index(text, selection.head);
}

#[cfg(feature = "components")]
fn reconcile_selection(selection: &mut RichSelection, old_text: &str, new_text: &str) {
    if old_text == new_text {
        clamp_selection(selection, new_text);
        return;
    }

    let range = selection.range();
    let preserved = old_text
        .get(range.clone())
        .and_then(|selected| new_text.get(range).filter(|current| *current == selected))
        .is_some();
    if preserved {
        clamp_selection(selection, new_text);
    } else {
        selection.clear();
    }
}

#[cfg(feature = "components")]
fn clamp_byte_index(text: &str, index: usize) -> usize {
    let mut index = index.min(text.len());
    while !text.is_char_boundary(index) {
        index = index.saturating_sub(1);
    }
    index
}

#[cfg(feature = "components")]
fn byte_to_character_index(text: &str, byte: usize) -> usize {
    text[..clamp_byte_index(text, byte)].chars().count()
}

#[cfg(feature = "components")]
fn native_runs(text: &str, runs: &[RichTextRunNode]) -> Vec<NativeRichRun> {
    runs.iter()
        .filter_map(|run| {
            let start = text_position_to_byte(text, &run.range.start)?;
            let end = text_position_to_byte(text, &run.range.end)?;
            (start < end).then(|| NativeRichRun {
                range: start..end,
                source: run.clone(),
            })
        })
        .collect()
}

#[cfg(feature = "components")]
fn text_position_to_byte(text: &str, position: &TextPosition) -> Option<usize> {
    let line = usize::try_from(position.line).ok()?;
    let target = usize::try_from(position.utf16_offset).ok()?;
    let line_start = text
        .split_inclusive('\n')
        .take(line)
        .map(str::len)
        .sum::<usize>();
    let line_text = text.get(line_start..)?.split('\n').next()?;
    if target == line_text.encode_utf16().count() {
        return Some(line_start + line_text.len());
    }
    let mut utf16 = 0;
    for (byte, character) in line_text.char_indices() {
        if utf16 == target {
            return Some(line_start + byte);
        }
        utf16 += character.len_utf16();
        if utf16 > target {
            return None;
        }
    }
    None
}

#[cfg(feature = "components")]
fn shaped_runs(
    base: &gpui::TextStyle,
    text_len: usize,
    runs: &[NativeRichRun],
) -> Vec<gpui::TextRun> {
    let mut result = Vec::new();
    let mut offset = 0;
    for run in runs {
        if offset < run.range.start {
            result.push(base.to_run(run.range.start - offset));
        }
        let mut text_run = base.to_run(run.range.len());
        apply_run_style(&mut text_run, &run.source);
        result.push(text_run);
        offset = run.range.end;
    }
    if offset < text_len {
        result.push(base.to_run(text_len - offset));
    }
    if result.is_empty() {
        result.push(base.to_run(0));
    }
    result
}

#[cfg(feature = "components")]
fn apply_run_style(run: &mut gpui::TextRun, source: &RichTextRunNode) {
    if let Some(color) = source.color {
        run.color = gpui::rgb(color).into();
    }
    run.background_color = source.background.map(|color| gpui::rgb(color).into());
    run.font.weight = match source.font_weight.as_deref() {
        Some("thin") => gpui::FontWeight::THIN,
        Some("extra_light") => gpui::FontWeight::EXTRA_LIGHT,
        Some("light") => gpui::FontWeight::LIGHT,
        Some("medium") => gpui::FontWeight::MEDIUM,
        Some("semibold") => gpui::FontWeight::SEMIBOLD,
        Some("bold") => gpui::FontWeight::BOLD,
        Some("extra_bold") => gpui::FontWeight::EXTRA_BOLD,
        Some("black") => gpui::FontWeight::BLACK,
        _other => run.font.weight,
    };
    run.font.style = match source.font_style.as_deref() {
        Some("italic") => gpui::FontStyle::Italic,
        Some("oblique") => gpui::FontStyle::Oblique,
        _other => run.font.style,
    };
    run.underline = source.underline.map(|color| gpui::UnderlineStyle {
        color: Some(gpui::rgb(color).into()),
        thickness: gpui::px(1.0),
        wavy: source.underline_style.as_deref() == Some("wavy"),
    });
    run.strikethrough = source.strikethrough.map(|color| gpui::StrikethroughStyle {
        color: Some(gpui::rgb(color).into()),
        thickness: gpui::px(1.0),
    });
}

#[cfg(feature = "components")]
fn paint_selection(
    selection: &Range<usize>,
    layout: &gpui::TextLayout,
    bounds: gpui::Bounds<gpui::Pixels>,
    window: &mut gpui::Window,
) {
    if selection.is_empty() {
        return;
    }
    let (Some(start), Some(end)) = (
        layout.position_for_index(selection.start),
        layout.position_for_index(selection.end),
    ) else {
        return;
    };
    let line_height = layout.line_height();
    let color = gpui::rgba(0x3B82F680);
    if start.y == end.y {
        window.paint_quad(gpui::fill(
            gpui::Bounds::from_corners(start, gpui::point(end.x, end.y + line_height)),
            color,
        ));
        return;
    }
    window.paint_quad(gpui::fill(
        gpui::Bounds::from_corners(start, gpui::point(bounds.right(), start.y + line_height)),
        color,
    ));
    if end.y > start.y + line_height {
        window.paint_quad(gpui::fill(
            gpui::Bounds::from_corners(
                gpui::point(bounds.left(), start.y + line_height),
                gpui::point(bounds.right(), end.y),
            ),
            color,
        ));
    }
    window.paint_quad(gpui::fill(
        gpui::Bounds::from_corners(
            gpui::point(bounds.left(), end.y),
            gpui::point(end.x, end.y + line_height),
        ),
        color,
    ));
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: RichTextComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, Vec::new(), context)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preserves_selection_when_streaming_appends_after_the_selected_range() {
        let mut selection = RichSelection {
            anchor: 1,
            head: 5,
            dragging: false,
        };
        reconcile_selection(&mut selection, "Hello", "Hello streamed tail");
        assert_eq!(selection.range(), 1..5);

        reconcile_selection(&mut selection, "Hello streamed tail", "Hxllo streamed tail");
        assert!(selection.range().is_empty());
    }

    #[test]
    fn clamps_selection_to_utf8_boundaries_and_normalizes_backward_ranges() {
        let text = "A😀B";
        let mut selection = RichSelection {
            anchor: 4,
            head: 2,
            dragging: true,
        };
        clamp_selection(&mut selection, text);

        assert_eq!(selection.anchor, 1);
        assert_eq!(selection.head, 1);
        assert!(selection.range().is_empty());

        selection.anchor = text.len();
        selection.head = 1;
        assert_eq!(selection.range(), 1..text.len());
        assert_eq!(byte_to_character_index(text, text.len()), 3);
        assert_eq!(byte_to_character_index(text, 5), 2);
    }

    #[test]
    fn converts_utf16_positions_without_splitting_surrogates() {
        let text = "A😀B\nsecond";
        assert_eq!(
            text_position_to_byte(
                text,
                &TextPosition {
                    line: 0,
                    utf16_offset: 1
                }
            ),
            Some(1)
        );
        assert_eq!(
            text_position_to_byte(
                text,
                &TextPosition {
                    line: 0,
                    utf16_offset: 2
                }
            ),
            None
        );
        assert_eq!(
            text_position_to_byte(
                text,
                &TextPosition {
                    line: 0,
                    utf16_offset: 3
                }
            ),
            Some(5)
        );
        assert_eq!(
            text_position_to_byte(
                text,
                &TextPosition {
                    line: 1,
                    utf16_offset: 2
                }
            ),
            Some(9)
        );
    }
}
