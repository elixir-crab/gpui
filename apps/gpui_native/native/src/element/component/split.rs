use crate::element::ElementRenderContext;
use crate::{gpui, SplitComponentNode};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
pub(crate) struct ComponentSplit {
    pub(crate) state: gpui::Entity<gpui_component::resizable::ResizableState>,
    pub(crate) change_event: std::sync::Arc<std::sync::Mutex<Option<String>>>,
    pub(crate) orientation: gpui::Axis,
    pub(crate) resize_request: u64,
}

#[cfg(feature = "components")]
pub(crate) fn render(
    node: SplitComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use crate::{push_event, EventValue, InputKind, NativeEvent};
    use gpui::{AppContext, IntoElement, ParentElement, Styled};
    use gpui_component::resizable::{resizable_panel, ResizablePanelGroup, ResizableState};
    use std::sync::{Arc, Mutex};

    if node.children.len() != 2 || !valid_pairs(&node.sizes, &node.min_sizes, &node.max_sizes) {
        return apply_component_styles(gpui::div(), node.style).into_any_element();
    }

    let orientation = if node.orientation.as_deref() == Some("vertical") {
        gpui::Axis::Vertical
    } else {
        gpui::Axis::Horizontal
    };
    let rebuild = context
        .components
        .split_mut(&node.id)
        .map(|split| split.orientation != orientation)
        .unwrap_or(true);

    if rebuild {
        let state = context.cx.new(|_| ResizableState::default());
        context.components.insert_split(
            &node.id,
            ComponentSplit {
                state,
                change_event: Arc::new(Mutex::new(node.change.clone())),
                orientation,
                resize_request: node.resize_request,
            },
        );
    }

    let split = context
        .components
        .split_mut(&node.id)
        .expect("component split should exist");
    if let Ok(mut event) = split.change_event.lock() {
        *event = node.change.clone();
    }
    if node.resize_request > split.resize_request {
        let first_size = gpui::px(node.sizes[0] as f32);
        split.state.update(context.cx, |state, cx| {
            state.resize_panel(0, first_size, context.window, cx)
        });
        split.resize_request = node.resize_request;
    }

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let change_event = split.change_event.clone();
    let state = split.state.clone();
    let children = node.children;
    let first = children[0].clone().render(context);
    let second = children[1].clone().render(context);

    let first_panel = resizable_panel()
        .size(gpui::px(node.sizes[0] as f32))
        .size_range(gpui::px(node.min_sizes[0] as f32)..gpui::px(node.max_sizes[0] as f32))
        .child(first);
    let second_panel = resizable_panel()
        .size(gpui::px(node.sizes[1] as f32))
        .size_range(gpui::px(node.min_sizes[1] as f32)..gpui::px(node.max_sizes[1] as f32))
        .child(second);

    let element = ResizablePanelGroup::new(node.id)
        .axis(orientation)
        .with_state(&state)
        .children([first_panel, second_panel])
        .on_resize(move |state, _window, _cx| {
            let event = change_event.lock().ok().and_then(|event| event.clone());
            if let Some(event) = event {
                let sizes = state
                    .read(_cx)
                    .sizes()
                    .iter()
                    .map(|size| f64::from(*size))
                    .collect::<Vec<_>>();
                let _ = push_event(
                    &runtime,
                    NativeEvent::Input {
                        kind: InputKind::Change,
                        window_id,
                        event,
                        value: Some(EventValue::Numbers(sizes)),
                    },
                );
            }
        });

    apply_component_styles(gpui::div().size_full().child(element), node.style).into_any_element()
}

#[cfg(feature = "components")]
fn valid_pairs(sizes: &[f64], mins: &[f64], maxes: &[f64]) -> bool {
    sizes.len() == 2
        && mins.len() == 2
        && maxes.len() == 2
        && (0..2).all(|index| {
            sizes[index].is_finite()
                && mins[index].is_finite()
                && maxes[index].is_finite()
                && mins[index] >= 0.0
                && mins[index] <= sizes[index]
                && sizes[index] <= maxes[index]
                && maxes[index] <= 100_000.0
        })
}

#[cfg(not(feature = "components"))]
pub(crate) fn render(
    node: SplitComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    render_component_fallback(node.style, None, node.children, context)
}
