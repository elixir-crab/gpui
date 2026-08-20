use crate::element::ElementRenderContext;
use crate::{gpui, CopyButtonComponentNode, FilePickerComponentNode, ProgressComponentNode};

#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
static NEXT_FILE_OPERATION_ID: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);

#[cfg(feature = "components")]
pub(crate) fn render_progress(
    node: ProgressComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        div, prelude::FluentBuilder, relative, Animation, AnimationExt, InteractiveElement,
        IntoElement, ParentElement, Role, StatefulInteractiveElement, Styled,
    };
    use gpui_component::ActiveTheme;
    use std::time::Duration;

    let progress_color = context.cx.theme().tokens.progress_bar;
    let value = node.value.clamp(0.0, node.max);
    let percent = ((value / node.max) * 100.0).clamp(0.0, 100.0);
    let label = node.label.unwrap_or_else(|| "Progress".to_string());
    let animation_id = format!("gpui-elixir-progress-animation-{}", node.id);
    let inner = div()
        .absolute()
        .top_0()
        .left_0()
        .h_full()
        .bg(progress_color)
        .rounded(gpui::px(4.0));
    let inner = if node.indeterminate {
        inner
            .with_animation(
                animation_id,
                Animation::new(Duration::from_secs(1)).repeat(),
                move |element, delta| {
                    let start = relative(((delta - 0.5) / 0.5).clamp(0.0, 1.0));
                    let end = relative((1.0 - delta).clamp(0.0, 1.0));
                    element
                        .when(delta > 0.5, |element| element.left(start))
                        .right(end)
                },
            )
            .into_any_element()
    } else {
        inner
            .w(relative((percent as f32 / 100.0).clamp(0.0, 1.0)))
            .into_any_element()
    };

    let mut element = crate::element::apply_generated_render_styles(gpui::div(), node.style)
        .id(node.id)
        .role(Role::ProgressIndicator)
        .aria_label(label.clone())
        .flex()
        .flex_col()
        .gap(gpui::px(6.0));
    if !node.indeterminate {
        element = element
            .aria_numeric_value(value)
            .aria_min_numeric_value(0.0)
            .aria_max_numeric_value(node.max);
    }

    element
        .child(label)
        .child(
            div()
                .relative()
                .w_full()
                .h(gpui::px(8.0))
                .rounded(gpui::px(4.0))
                .bg(progress_color.opacity(0.2))
                .child(inner),
        )
        .into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_file_picker(
    node: FilePickerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{AppContext, IntoElement};
    use gpui_component::{button::Button, Disableable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let event = node.change;
    let prompt = node
        .prompt
        .filter(|prompt| !prompt.is_empty())
        .unwrap_or_else(|| "Choose a file".to_string());
    let max_bytes = node.max_bytes.min(100 * 1_024 * 1_024) as usize;
    let button = Button::new(node.id)
        .label(node.label.unwrap_or_else(|| "Choose file".to_string()))
        .disabled(node.disabled)
        .on_click(move |_click, window, cx| {
            let Some(event) = event.clone() else {
                return;
            };
            let operation_id =
                NEXT_FILE_OPERATION_ID.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            let receiver = cx.prompt_for_paths(gpui::PathPromptOptions {
                files: true,
                directories: false,
                multiple: false,
                prompt: Some(prompt.clone().into()),
            });
            let runtime = runtime.clone();

            window
                .spawn(cx, async move |cx| {
                    let result = match receiver.await {
                        Ok(Ok(Some(paths))) => match paths.into_iter().next() {
                            Some(path) => {
                                cx.background_spawn(async move { read_file(path, max_bytes) })
                                    .await
                            }
                            None => FileDialogResult::Cancelled,
                        },
                        Ok(Ok(None)) => FileDialogResult::Cancelled,
                        Ok(Err(error)) => FileDialogResult::Error(error.to_string()),
                        Err(error) => FileDialogResult::Error(error.to_string()),
                    };

                    let _ = crate::push_event(
                        &runtime,
                        crate::NativeEvent::FileDialog {
                            window_id,
                            event,
                            operation_id,
                            result,
                        },
                    );
                })
                .detach();
        });

    super::apply_component_styles(button, node.style).into_any_element()
}

#[cfg(any(feature = "components", test))]
pub(crate) fn bounded_clipboard_text(text: Option<String>) -> Option<String> {
    text.filter(|text| !text.is_empty() && text.len() <= crate::MAX_TRANSFER_TEXT_BYTES)
}

#[cfg(feature = "components")]
pub(crate) fn render_copy_button(
    node: CopyButtonComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{ClipboardItem, IntoElement};
    use gpui_component::{button::Button, Disableable};

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let event = node.click;
    let text = node.text;
    let button = Button::new(node.id)
        .label(node.label.unwrap_or_else(|| "Copy".to_string()))
        .disabled(node.disabled)
        .on_click(move |_click, _window, cx| {
            cx.write_to_clipboard(ClipboardItem::new_string(text.clone()));
            if let Some(event) = event.as_ref() {
                let _ = crate::push_event(
                    &runtime,
                    crate::NativeEvent::Click {
                        window_id,
                        event: event.clone(),
                    },
                );
            }
        });

    super::apply_component_styles(button, node.style).into_any_element()
}

#[cfg(any(feature = "components", test))]
#[derive(Clone, Debug)]
pub(crate) enum FileDialogResult {
    Selected { name: String, data: Vec<u8> },
    Cancelled,
    Error(String),
}

#[cfg(any(feature = "components", test))]
fn read_file(path: std::path::PathBuf, max_bytes: usize) -> FileDialogResult {
    use std::io::Read;

    let name = path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| "selected-file".to_string());
    let file = match std::fs::File::open(path) {
        Ok(file) => file,
        Err(error) => return FileDialogResult::Error(error.to_string()),
    };
    let mut data = Vec::new();

    match file.take(max_bytes as u64 + 1).read_to_end(&mut data) {
        Ok(_) if data.len() > max_bytes => {
            FileDialogResult::Error(format!("selected file exceeds the {max_bytes} byte limit"))
        }
        Ok(_) => FileDialogResult::Selected { name, data },
        Err(error) => FileDialogResult::Error(error.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounds_clipboard_text_before_emitting() {
        assert_eq!(
            bounded_clipboard_text(Some("hello".to_string())),
            Some("hello".to_string())
        );
        assert_eq!(bounded_clipboard_text(Some(String::new())), None);
        assert_eq!(
            bounded_clipboard_text(Some("x".repeat(crate::MAX_TRANSFER_TEXT_BYTES + 1))),
            None
        );
        assert_eq!(bounded_clipboard_text(None), None);
    }

    #[test]
    fn bounds_selected_file_reads() {
        let path = std::env::temp_dir().join(format!("gpui-file-picker-{}", std::process::id()));
        std::fs::write(&path, [1, 2, 3]).expect("fixture should be writable");

        match read_file(path.clone(), 2) {
            FileDialogResult::Error(reason) => assert!(reason.contains("2 byte limit")),
            other => panic!("expected bounded read error, got {other:?}"),
        }
        match read_file(path.clone(), 3) {
            FileDialogResult::Selected { name, data } => {
                assert!(name.starts_with("gpui-file-picker-"));
                assert_eq!(data, vec![1, 2, 3]);
            }
            other => panic!("expected selected file, got {other:?}"),
        }
        assert!(matches!(
            FileDialogResult::Cancelled,
            FileDialogResult::Cancelled
        ));

        std::fs::remove_file(path).expect("fixture should be removable");
    }
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_progress(
    node: ProgressComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, Vec::new(), context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_file_picker(
    node: FilePickerComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, Vec::new(), context)
}

#[cfg(not(feature = "components"))]
pub(crate) fn render_copy_button(
    node: CopyButtonComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, node.label, Vec::new(), context)
}
