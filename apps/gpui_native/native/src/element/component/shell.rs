use crate::element::{ElementNode, ElementRenderContext};
use crate::{
    gpui, SeparatorComponentNode, SidebarComponentNode, SidebarGroupComponentNode,
    SidebarHeaderComponentNode, SidebarItemComponentNode, SidebarMenuComponentNode,
    StatusBarComponentNode, StatusItemComponentNode,
};

#[cfg(feature = "components")]
use super::apply_component_styles;
#[cfg(not(feature = "components"))]
use super::render_component_fallback;

#[cfg(feature = "components")]
fn render_children(
    children: Vec<ElementNode>,
    context: &mut ElementRenderContext<'_, '_>,
) -> Vec<gpui::AnyElement> {
    children
        .into_iter()
        .map(|child| child.render(context))
        .collect()
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct AccessibleSidebarItem {
    visual: gpui_component::sidebar::SidebarMenuItem,
    id: String,
    label: String,
    active: bool,
    disabled: bool,
    event: Option<String>,
    runtime: crate::SharedRuntime,
    window_id: u64,
    focus: gpui::FocusHandle,
}

#[cfg(feature = "components")]
impl gpui_component::Collapsible for AccessibleSidebarItem {
    fn collapsed(mut self, collapsed: bool) -> Self {
        self.visual = gpui_component::Collapsible::collapsed(self.visual, collapsed);
        self
    }

    fn is_collapsed(&self) -> bool {
        gpui_component::Collapsible::is_collapsed(&self.visual)
    }
}

#[cfg(feature = "components")]
impl gpui_component::sidebar::SidebarItem for AccessibleSidebarItem {
    fn render(
        self,
        id: impl Into<gpui::ElementId>,
        window: &mut gpui::Window,
        cx: &mut gpui::App,
    ) -> impl gpui::IntoElement {
        use gpui::{InteractiveElement, IntoElement, ParentElement};

        let visual = self.visual.render(id, window, cx).into_any_element();
        let accessibility = crate::AccessibilitySemantics {
            role: Some(crate::AccessibilityRole::Button),
            label: Some(self.label),
            selected: Some(self.active),
            disabled: self.disabled,
            ..Default::default()
        };
        let wrapper = gpui::div()
            .id(format!("{}-accessible", self.id))
            .child(visual);

        match self.event {
            Some(event) => crate::element::event::attach_accessible_action_target(
                wrapper,
                self.id,
                event,
                accessibility,
                self.runtime,
                self.window_id,
                self.focus,
            ),
            None => crate::element::apply_accessibility_semantics(wrapper, accessibility),
        }
    }
}

#[cfg(feature = "components")]
fn sidebar_item(
    node: SidebarItemComponentNode,
    context: &ElementRenderContext<'_, '_>,
) -> AccessibleSidebarItem {
    use gpui_component::sidebar::SidebarMenuItem;

    let runtime = context.runtime.clone();
    let window_id = context.window_id;
    let event = node.click.clone();
    let visual_event = node.click;
    let visual_runtime = runtime.clone();
    let label = node.label.clone();
    let visual = SidebarMenuItem::new(node.label)
        .active(node.active)
        .disable(node.disabled)
        .on_click(move |_click, _window, _cx| {
            if let Some(event) = visual_event.as_ref() {
                crate::element::event::emit_click_event(&visual_runtime, window_id, event);
            }
        });

    AccessibleSidebarItem {
        visual,
        id: node.id,
        label,
        active: node.active,
        disabled: node.disabled,
        event,
        runtime,
        window_id,
        focus: context.cx.focus_handle(),
    }
}

#[cfg(feature = "components")]
#[derive(Clone)]
struct AccessibleSidebarMenu {
    items: Vec<AccessibleSidebarItem>,
}

#[cfg(feature = "components")]
impl gpui_component::Collapsible for AccessibleSidebarMenu {
    fn collapsed(mut self, collapsed: bool) -> Self {
        self.items = self
            .items
            .into_iter()
            .map(|item| gpui_component::Collapsible::collapsed(item, collapsed))
            .collect();
        self
    }

    fn is_collapsed(&self) -> bool {
        false
    }
}

#[cfg(feature = "components")]
impl gpui_component::sidebar::SidebarItem for AccessibleSidebarMenu {
    fn render(
        self,
        id: impl Into<gpui::ElementId>,
        window: &mut gpui::Window,
        cx: &mut gpui::App,
    ) -> impl gpui::IntoElement {
        use gpui::{IntoElement, ParentElement, Styled};

        let id: gpui::ElementId = id.into();
        gpui_component::v_flex()
            .gap_2()
            .children(self.items.into_iter().enumerate().map(|(index, item)| {
                item.render(format!("{id}-{index}"), window, cx)
                    .into_any_element()
            }))
    }
}

#[cfg(feature = "components")]
fn sidebar_menu(
    node: SidebarMenuComponentNode,
    context: &ElementRenderContext<'_, '_>,
) -> AccessibleSidebarMenu {
    let items = node.children.into_iter().filter_map(|child| match child {
        ElementNode::SidebarItemComponent(item) => Some(sidebar_item(item, context)),
        _ => None,
    });

    AccessibleSidebarMenu {
        items: items.collect(),
    }
}

#[cfg(feature = "components")]
fn sidebar_group(
    node: SidebarGroupComponentNode,
    context: &ElementRenderContext<'_, '_>,
) -> gpui_component::sidebar::SidebarGroup<AccessibleSidebarMenu> {
    use gpui_component::sidebar::SidebarGroup;

    let menus = node.children.into_iter().filter_map(|child| match child {
        ElementNode::SidebarMenuComponent(menu) => Some(sidebar_menu(menu, context)),
        _ => None,
    });

    SidebarGroup::<AccessibleSidebarMenu>::new(node.label).children(menus)
}

#[cfg(feature = "components")]
pub(crate) fn render_sidebar_component(
    node: SidebarComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};
    use gpui_component::sidebar::{Sidebar, SidebarCollapsible, SidebarGroup};

    let side = if node.side.as_deref() == Some("right") {
        gpui_component::Side::Right
    } else {
        gpui_component::Side::Left
    };
    let collapsible = match node.collapsible.as_deref() {
        Some("icon") => SidebarCollapsible::Icon,
        Some("offcanvas") => SidebarCollapsible::Offcanvas,
        _ => SidebarCollapsible::None,
    };

    let mut header = None;
    let mut groups: Vec<SidebarGroup<AccessibleSidebarMenu>> = Vec::new();
    for child in node.children {
        match child {
            ElementNode::SidebarHeaderComponent(header_node) => {
                header = Some(
                    gpui_component::sidebar::SidebarHeader::new()
                        .children(render_children(header_node.children, context)),
                );
            }
            ElementNode::SidebarGroupComponent(group) => groups.push(sidebar_group(group, context)),
            _ => {}
        }
    }

    let mut sidebar = Sidebar::new(node.id)
        .side(side)
        .collapsible(collapsible)
        .collapsed(node.collapsed)
        .children(groups);
    if let Some(header) = header {
        sidebar = sidebar.header(header);
    }

    apply_component_styles(sidebar, node.style).into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_sidebar_header_component(
    node: SidebarHeaderComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};
    use gpui_component::sidebar::SidebarHeader;

    apply_component_styles(
        SidebarHeader::new().children(render_children(node.children, context)),
        node.style,
    )
    .into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_sidebar_group_component(
    node: SidebarGroupComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement, Styled};

    apply_component_styles(gpui::div(), node.style)
        .flex()
        .flex_col()
        .child(
            gpui::div()
                .h(gpui::px(32.0))
                .px(gpui::px(8.0))
                .flex()
                .items_center()
                .child(node.label),
        )
        .children(render_children(node.children, context))
        .into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_sidebar_menu_component(
    node: SidebarMenuComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement};

    apply_component_styles(gpui::div(), node.style)
        .children(render_children(node.children, context))
        .into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_sidebar_item_component(
    node: SidebarItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::IntoElement;
    use gpui_component::sidebar::SidebarItem;

    sidebar_item(node, context)
        .render("standalone-sidebar-item", context.window, context.cx)
        .into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_status_bar_component(
    node: StatusBarComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::IntoElement;
    use gpui_component::status_bar::StatusBar;

    let mut bar = StatusBar::new();
    for child in node.children {
        match child {
            ElementNode::StatusItemComponent(item) => {
                let side = item.side.clone();
                let element = render_status_item_component(item, context);
                match side.as_deref() {
                    Some("left") => bar = bar.left(element),
                    Some("right") => bar = bar.right(element),
                    _ => bar = gpui::ParentElement::child(bar, element),
                }
            }
            child => bar = gpui::ParentElement::child(bar, child.render(context)),
        }
    }

    apply_component_styles(bar, node.style).into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_status_item_component(
    node: StatusItemComponentNode,
    context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement, Styled};

    apply_component_styles(gpui::div(), node.style)
        .flex()
        .items_center()
        .gap(gpui::px(8.0))
        .children(render_children(node.children, context))
        .into_any_element()
}

#[cfg(feature = "components")]
pub(crate) fn render_separator_component(
    node: SeparatorComponentNode,
    _context: &mut ElementRenderContext<'_, '_>,
) -> gpui::AnyElement {
    use gpui::IntoElement;
    use gpui_component::separator::Separator;

    let mut separator = if node.orientation.as_deref() == Some("vertical") {
        Separator::vertical()
    } else {
        Separator::horizontal()
    };
    if node.dashed {
        separator = separator.dashed();
    }
    if let Some(label) = node.label {
        separator = separator.label(label);
    }
    apply_component_styles(separator, node.style).into_any_element()
}

#[cfg(not(feature = "components"))]
macro_rules! fallback_renderer {
    ($name:ident, $node:ty) => {
        pub(crate) fn $name(
            node: $node,
            context: &mut ElementRenderContext<'_, '_>,
        ) -> gpui::AnyElement {
            render_component_fallback(node.style, None, node.children, context)
        }
    };
}

#[cfg(not(feature = "components"))]
fallback_renderer!(render_sidebar_component, SidebarComponentNode);
#[cfg(not(feature = "components"))]
fallback_renderer!(render_sidebar_header_component, SidebarHeaderComponentNode);
#[cfg(not(feature = "components"))]
fallback_renderer!(render_sidebar_group_component, SidebarGroupComponentNode);
#[cfg(not(feature = "components"))]
fallback_renderer!(render_sidebar_menu_component, SidebarMenuComponentNode);
#[cfg(not(feature = "components"))]
fallback_renderer!(render_status_bar_component, StatusBarComponentNode);
#[cfg(not(feature = "components"))]
fallback_renderer!(render_status_item_component, StatusItemComponentNode);
