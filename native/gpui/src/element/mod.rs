use crate::*;

pub(crate) mod component;
#[cfg(feature = "components")]
pub(crate) mod component_registry;
pub(crate) mod controlled;
pub(crate) mod event;

use event::{apply_click_event, apply_input_events};

#[cfg(feature = "real-gpui")]
pub(crate) struct ElementRenderContext<'a, 'cx> {
    pub(crate) runtime: SharedRuntime,
    pub(crate) window_id: u64,
    pub(crate) next_element_id: usize,
    pub(crate) id_namespace: String,
    pub(crate) active_input_ids: &'a mut HashSet<String>,
    pub(crate) input_entities: &'a mut HashMap<String, gpui::Entity<NativeTextInput>>,
    #[cfg(feature = "components")]
    pub(crate) components: &'a mut component_registry::ComponentRegistry,
    pub(crate) window: &'a mut gpui::Window,
    pub(crate) cx: &'a mut gpui::Context<'cx, ElixirRoot>,
}

#[cfg(feature = "real-gpui")]
impl ElementRenderContext<'_, '_> {
    fn allocate_element_id(&mut self) -> usize {
        let element_id = self.next_element_id;
        self.next_element_id += 1;
        element_id
    }
}

#[cfg(feature = "real-gpui")]
impl ElementNode {
    pub(crate) fn empty_root() -> Self {
        Self::Div(ContainerNode {
            tag: GeneratedElementTag::Div,
            style: StyleAttrs::default(),
            id: None,
            accessibility: AccessibilitySemantics::default(),
            children: Vec::new(),
            click: None,
            bounds_change: None,
            focus_request: 0,
            focus: None,
            blur: None,
        })
    }

    pub(crate) fn render(self, context: &mut ElementRenderContext<'_, '_>) -> gpui::AnyElement {
        let element_id = context.allocate_element_id();

        match self {
            Self::Viewport(node) => render_viewport_primitive(node.children, context),
            Self::Text(node) => render_text_primitive(node.text, node.style),
            Self::Image(node) => render_image_primitive(
                node.image,
                node.style,
                node.label,
                format!("{}-image-{element_id}", context.id_namespace),
                context.runtime.clone(),
                context.window_id,
            ),
            Self::Input(input) => render_input_primitive(element_id, input, context),
            Self::AnchoredLayer(layer) => render_anchored_layer_primitive(layer, context),
            Self::TextSurface(surface) => {
                render_text_surface_primitive(element_id, surface, context)
            }
            Self::Div(node) => render_container_primitive(element_id, node, context),
            component => render_generated_component_node(component, element_id, context),
        }
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_anchored_layer_primitive(
    layer: AnchoredLayerNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{
        anchored, deferred, point, px, Anchor, AnchoredPositionMode, IntoElement, ParentElement,
    };

    let _stable_id = layer.id;
    let anchor = match layer.anchor.as_str() {
        "top_right" => Anchor::TopRight,
        "bottom_left" => Anchor::BottomLeft,
        "bottom_right" => Anchor::BottomRight,
        "top_center" => Anchor::TopCenter,
        "bottom_center" => Anchor::BottomCenter,
        "left_center" => Anchor::LeftCenter,
        "right_center" => Anchor::RightCenter,
        _ => Anchor::TopLeft,
    };
    let mut element = anchored()
        .anchor(anchor)
        .position_mode(if layer.position_mode == "window" {
            AnchoredPositionMode::Window
        } else {
            AnchoredPositionMode::Local
        })
        .offset(point(px(layer.offset_x as f32), px(layer.offset_y as f32)));
    if let (Some(x), Some(y)) = (layer.position_x, layer.position_y) {
        element = element.position(point(px(x as f32), px(y as f32)));
    }
    element = match layer.fit.as_str() {
        "snap_to_window" => element.snap_to_window(),
        "snap_with_margin" => element.snap_to_window_with_margin(px(layer.margin as f32)),
        _ => element,
    };
    for child in layer.children {
        element = element.child(child.render(context));
    }
    deferred(element)
        .with_priority(layer.priority as usize)
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn install_focus_observers(
    focus_handle: gpui::FocusHandle,
    id: String,
    runtime: SharedRuntime,
    window_id: u64,
    window: &mut gpui::Window,
    cx: &mut gpui::App,
) {
    let runtime_for_focus = runtime.clone();
    let id_for_focus = id.clone();
    window
        .on_focus_in(&focus_handle, cx, move |_window, _cx| {
            let event = runtime_for_focus
                .focus_bindings
                .lock()
                .ok()
                .and_then(|bindings| bindings.get(&(window_id, id_for_focus.clone())).cloned())
                .and_then(|(event, _blur)| event);
            if let Some(event) = event {
                let _ = push_event(
                    &runtime_for_focus,
                    NativeEvent::Focus {
                        kind: InputKind::Focus,
                        window_id,
                        event,
                        id: id_for_focus.clone(),
                    },
                );
            }
        })
        .detach();
    let runtime_for_blur = runtime.clone();
    let id_for_blur = id;
    window
        .on_focus_out(&focus_handle, cx, move |_event, _window, _cx| {
            let event = runtime_for_blur
                .focus_bindings
                .lock()
                .ok()
                .and_then(|bindings| bindings.get(&(window_id, id_for_blur.clone())).cloned())
                .and_then(|(_focus, event)| event);
            if let Some(event) = event {
                let _ = push_event(
                    &runtime_for_blur,
                    NativeEvent::Focus {
                        kind: InputKind::Blur,
                        window_id,
                        event,
                        id: id_for_blur.clone(),
                    },
                );
            }
        })
        .detach();
}

#[cfg(feature = "real-gpui")]
fn request_native_focus(
    focus_handle: &gpui::FocusHandle,
    id: String,
    focus_request: u64,
    runtime: SharedRuntime,
    window_id: u64,
    context: &mut ElementRenderContext<'_, '_>,
) {
    let request = runtime
        .focus_requests
        .lock()
        .map(|mut requests| {
            let previous = requests.insert((window_id, id), focus_request).unwrap_or(0);
            focus_request > 0 && focus_request != previous
        })
        .unwrap_or(false);
    if request {
        let requested_focus = focus_handle.clone();
        context.window.defer(context.cx, move |window, cx| {
            requested_focus.focus(window, cx)
        });
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_focus_contract(
    mut element: gpui::Div,
    id: String,
    focus_request: u64,
    focus_event: Option<String>,
    blur_event: Option<String>,
    tab_stop: bool,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::Div {
    use gpui::InteractiveElement;

    let focus_handle = context
        .runtime
        .focus_handles
        .lock()
        .ok()
        .map(|mut handles| {
            handles
                .entry((context.window_id, id.clone()))
                .or_insert_with(|| context.cx.focus_handle())
                .clone()
        })
        .unwrap_or_else(|| context.cx.focus_handle());
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    if let Ok(mut bindings) = runtime.focus_bindings.lock() {
        bindings.insert((window_id, id.clone()), (focus_event, blur_event));
    }
    let install = runtime
        .focus_observers
        .lock()
        .map(|mut observers| observers.insert((window_id, id.clone())))
        .unwrap_or(false);
    if install {
        install_focus_observers(
            focus_handle.clone(),
            id.clone(),
            runtime.clone(),
            window_id,
            context.window,
            context.cx,
        );
    }
    request_native_focus(
        &focus_handle,
        id,
        focus_request,
        runtime,
        window_id,
        context,
    );
    element = element.track_focus(&focus_handle.tab_stop(tab_stop));
    element
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_viewport_primitive(
    children: Vec<ElementNode>,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement, Styled};

    let viewport_size = context.window.viewport_size();

    div()
        .absolute()
        .inset_0()
        .w(viewport_size.width)
        .h(viewport_size.height)
        .flex()
        .flex_col()
        .children(children.into_iter().map(|child| child.render(context)))
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_text_primitive(text: String, style: StyleAttrs) -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement};

    apply_generated_render_styles(div(), style)
        .child(text)
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_image_primitive(
    image: ImageData,
    style: StyleAttrs,
    label: Option<String>,
    element_id: String,
    runtime: SharedRuntime,
    window_id: u64,
) -> gpui::AnyElement {
    use gpui::{
        div, InteractiveElement, IntoElement, ParentElement, Role, StatefulInteractiveElement,
    };

    let image = match image {
        ImageData::Raster(raster) => raster.render(),
        ImageData::Ref(resource_id) => {
            if let Some(raster) = runtime
                .resources
                .lock()
                .ok()
                .and_then(|resources| resources.get(&resource_id).cloned())
            {
                raster.render()
            } else {
                let _ = push_event(
                    &runtime,
                    NativeEvent::MissingResource {
                        window_id,
                        id: resource_id,
                    },
                );
                render_missing_resource_placeholder()
            }
        }
    };

    let mut element = apply_generated_render_styles(div(), style)
        .child(image)
        .id(element_id);
    if let Some(label) = label {
        element = element.role(Role::Image).aria_label(label);
    }
    element.into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_missing_resource_placeholder() -> gpui::AnyElement {
    use gpui::{div, IntoElement, ParentElement, Styled};

    div()
        .flex()
        .items_center()
        .justify_center()
        .border(gpui::px(1.0))
        .border_color(gpui::rgb(0xcc3333))
        .bg(gpui::rgb(0x332222))
        .text_color(gpui::rgb(0xffaaaa))
        .p(gpui::px(8.0))
        .child("missing resource")
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_accessibility_semantics(
    mut element: gpui::Stateful<gpui::Div>,
    accessibility: AccessibilitySemantics,
) -> gpui::Stateful<gpui::Div> {
    use gpui::StatefulInteractiveElement;

    if let Some(role) = accessibility.role {
        element = element.role(role.gpui_role());
    }
    if let Some(label) = accessibility.label {
        element = element.aria_label(label);
    }
    if let Some(description) = accessibility.description {
        element = element.aria_description(description);
    }
    if let Some(value) = accessibility.value {
        element = element.aria_value(value);
    }
    if let Some(selected) = accessibility.selected {
        element = element.aria_selected(selected);
    }
    if let Some(expanded) = accessibility.expanded {
        element = element.aria_expanded(expanded);
    }
    if let Some(checked) = accessibility.checked {
        element = element.aria_toggled(checked.toggled());
    }
    if let Some(orientation) = accessibility.orientation {
        element = element.aria_orientation(orientation.gpui_orientation());
    }
    if accessibility.disabled {
        element = element.a11y_synthetic_children(|builder| {
            builder.parent_node().set_disabled();
        });
    }
    element
}

#[cfg(feature = "real-gpui")]
pub(crate) fn apply_container_semantics(element: gpui::Div, tag: GeneratedElementTag) -> gpui::Div {
    use gpui::Styled;

    match tag {
        GeneratedElementTag::Button => element
            .cursor(gpui::CursorStyle::PointingHand)
            .rounded(gpui::px(6.0))
            .px(gpui::px(10.0))
            .py(gpui::px(6.0)),
        GeneratedElementTag::Scroll => element,
        GeneratedElementTag::List => element.flex().flex_col().gap(gpui::px(4.0)),
        GeneratedElementTag::Item => element.p(gpui::px(4.0)),
        GeneratedElementTag::Span => element,
        _ => element,
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_text_surface_primitive(
    element_id: usize,
    surface: TextSurfaceNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    component::text_surface::render(element_id, surface, context)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_input_primitive(
    element_id: usize,
    input_node: InputNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{div, AppContext, ParentElement};

    let InputNode {
        style,
        id: stable_id,
        value,
        placeholder,
        focus_request,
        change,
        keydown,
        keyup,
        focus,
        blur,
    } = input_node;
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let input_id = format!(
        "gpui-elixir-input-{window_id}-{}-{element_id}",
        context.id_namespace
    );
    let focus_enabled = focus_request > 0 || focus.is_some() || blur.is_some();
    let public_id = stable_id.unwrap_or_else(|| input_id.clone());
    if focus_enabled {
        if let Ok(mut bindings) = runtime.focus_bindings.lock() {
            bindings.insert(
                (window_id, public_id.clone()),
                (focus.clone(), blur.clone()),
            );
        }
    }
    context.active_input_ids.insert(input_id.clone());
    let input = if let Some(input) = context.input_entities.get(&input_id).cloned() {
        context.cx.update_entity(&input, |input, _cx| {
            input.update_props(value.clone(), placeholder.clone(), change.clone());
        });
        input
    } else {
        let input = context.cx.new(|cx| {
            NativeTextInput::new(
                input_id.clone(),
                runtime.clone(),
                window_id,
                value.clone(),
                placeholder.clone(),
                change.clone(),
                cx,
            )
        });
        context
            .input_entities
            .insert(input_id.clone(), input.clone());
        input
    };

    let focus_handle = input.read(context.cx).native_focus_handle();
    let install = if focus_enabled {
        runtime
            .focus_observers
            .lock()
            .map(|mut observers| observers.insert((window_id, public_id.clone())))
            .unwrap_or(false)
    } else {
        false
    };
    if install {
        install_focus_observers(
            focus_handle.clone(),
            public_id.clone(),
            runtime.clone(),
            window_id,
            context.window,
            context.cx,
        );
    }
    if focus_enabled {
        request_native_focus(
            &focus_handle,
            public_id,
            focus_request,
            runtime.clone(),
            window_id,
            context,
        );
    }

    let element = apply_generated_render_styles(div(), style).child(input);
    apply_input_events(element, input_id, keydown, keyup, runtime, window_id)
}

#[cfg(feature = "real-gpui")]
pub(crate) fn render_container_primitive(
    element_id: usize,
    node: ContainerNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{div, InteractiveElement, IntoElement, ParentElement, StatefulInteractiveElement};

    let ContainerNode {
        tag,
        style,
        id: stable_id,
        accessibility,
        children,
        click,
        bounds_change,
        focus_request,
        focus,
        blur,
    } = node;
    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let mut element = apply_generated_render_styles(div(), style);
    element = apply_container_semantics(element, tag);

    if let Some(event) = bounds_change {
        use gpui::Styled;

        let id = stable_id
            .clone()
            .expect("bounds-observed containers require stable IDs");
        let runtime_for_bounds = runtime.clone();
        let observer = gpui::canvas(
            move |bounds, _window, _cx| {
                let value = crate::event::ElementBoundsGeometry {
                    id: id.clone(),
                    x: f32::from(bounds.origin.x) as f64,
                    y: f32::from(bounds.origin.y) as f64,
                    width: f32::from(bounds.size.width) as f64,
                    height: f32::from(bounds.size.height) as f64,
                    coordinate_space: "window_native_pixels".to_string(),
                };
                let changed = runtime_for_bounds
                    .element_bounds
                    .lock()
                    .map(|mut known| {
                        let key = (window_id, id.clone());
                        if known.get(&key) == Some(&value)
                            || (known.len() >= 256 && !known.contains_key(&key))
                        {
                            false
                        } else {
                            known.insert(key, value.clone());
                            true
                        }
                    })
                    .unwrap_or(false);
                if changed {
                    let _ = push_event(
                        &runtime_for_bounds,
                        NativeEvent::Bounds {
                            window_id,
                            event: event.clone(),
                            value,
                        },
                    );
                }
            },
            |_bounds, _prepaint, _window, _cx| {},
        )
        .absolute()
        .inset_0();
        element = element.child(observer);
    }

    for child in children {
        element = element.child(child.render(context));
    }

    let mut accessibility = accessibility;
    if tag == GeneratedElementTag::Button {
        accessibility.role = Some(AccessibilityRole::Button);
    }

    if focus_request > 0 || focus.is_some() || blur.is_some() {
        let id = stable_id
            .clone()
            .expect("focus-enabled containers require stable IDs");
        element = apply_focus_contract(element, id, focus_request, focus, blur, true, context);
    }

    if tag == GeneratedElementTag::Scroll {
        let scroll_id = stable_id.clone().unwrap_or_else(|| {
            format!(
                "gpui-elixir-scroll-{window_id}-{}-{element_id}",
                context.id_namespace
            )
        });
        let element = element.id(scroll_id).overflow_y_scroll();
        let element = apply_accessibility_semantics(element, accessibility.clone());

        if let Some(event) = click {
            let runtime_for_click = runtime.clone();
            element
                .on_click(move |_event, _window, _cx| {
                    let _ = push_event(
                        &runtime_for_click,
                        NativeEvent::Click {
                            window_id,
                            event: event.clone(),
                        },
                    );
                })
                .into_any_element()
        } else {
            element.into_any_element()
        }
    } else {
        let element_id =
            stable_id.unwrap_or_else(|| format!("{}-{element_id}", context.id_namespace));
        apply_click_event(
            element,
            element_id,
            click,
            accessibility,
            runtime,
            window_id,
        )
    }
}
