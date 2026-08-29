use super::component::code_viewer::ComponentCodeViewer;
use super::component::data_table::ComponentDataTable;
use super::component::drop_target::ComponentDropTarget;
use super::component::rich_text::ComponentRichText;
use super::component::tree::ComponentTree;
use super::component::virtual_collection::ComponentVirtualCollection;
use super::component::virtual_list::ComponentVirtualList;
use super::controlled::SharedBinding;
use crate::element::component::split::ComponentSplit;
use crate::element::component::text_surface::ComponentTextSurface;
use crate::{gpui, push_event, EventValue, InputKind, NativeEvent, SharedRuntime};
use gpui_component::{
    combobox::ComboboxState,
    input::InputState,
    menu::PopupMenu,
    searchable_list::{SearchableListDelegate, SearchableListItem},
    select::SelectState,
    slider::SliderState,
    IndexPath,
};
use std::{
    collections::{HashMap, HashSet},
    hash::Hash,
    sync::{Arc, Mutex},
};

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct NativeSelectOption {
    pub(crate) label: gpui::SharedString,
    pub(crate) value: gpui::SharedString,
}

impl SearchableListItem for NativeSelectOption {
    type Value = gpui::SharedString;

    fn title(&self) -> gpui::SharedString {
        self.label.clone()
    }

    fn value(&self) -> &Self::Value {
        &self.value
    }
}

pub(crate) type SharedEvent = Arc<Mutex<Option<String>>>;
pub(crate) type SharedQuery = Arc<Mutex<String>>;

#[derive(Clone)]
pub(crate) struct NativeComboboxDelegate {
    all: Vec<NativeSelectOption>,
    filtered: Vec<NativeSelectOption>,
    runtime: SharedRuntime,
    window_id: u64,
    search_event: SharedEvent,
    query: SharedQuery,
}

impl NativeComboboxDelegate {
    pub(crate) fn new(
        all: Vec<NativeSelectOption>,
        runtime: SharedRuntime,
        window_id: u64,
        search_event: SharedEvent,
        query: SharedQuery,
    ) -> Self {
        let current_query = query.lock().map(|query| query.clone()).unwrap_or_default();
        let filtered = filter_options(&all, &current_query);
        Self {
            all,
            filtered,
            runtime,
            window_id,
            search_event,
            query,
        }
    }
}

impl SearchableListDelegate for NativeComboboxDelegate {
    type Item = NativeSelectOption;

    fn items_count(&self, section: usize) -> usize {
        if section == 0 {
            self.filtered.len()
        } else {
            0
        }
    }

    fn item(&self, index: IndexPath) -> Option<&Self::Item> {
        (index.section == 0)
            .then(|| self.filtered.get(index.row))
            .flatten()
    }

    fn position<V>(&self, value: &V) -> Option<IndexPath>
    where
        Self::Item: SearchableListItem<Value = V>,
        V: PartialEq,
    {
        self.filtered
            .iter()
            .position(|item| item.value() == value)
            .map(IndexPath::new)
    }

    fn perform_search(
        &mut self,
        query: &str,
        _window: &mut gpui::Window,
        _cx: &mut gpui::App,
    ) -> gpui::Task<()> {
        self.filtered = filter_options(&self.all, query);
        if let Ok(mut current_query) = self.query.lock() {
            *current_query = query.to_string();
        }

        let event = self
            .search_event
            .lock()
            .ok()
            .and_then(|event| event.clone());
        if let Some(event) = event {
            let _ = push_event(
                &self.runtime,
                NativeEvent::Input {
                    kind: InputKind::Search,
                    window_id: self.window_id,
                    event,
                    value: Some(EventValue::String(query.to_string())),
                },
            );
        }

        gpui::Task::ready(())
    }
}

pub(crate) fn filter_options(
    options: &[NativeSelectOption],
    query: &str,
) -> Vec<NativeSelectOption> {
    if query.is_empty() {
        return options.to_vec();
    }

    let query = query.to_lowercase();
    options
        .iter()
        .filter(|option| option.label.to_lowercase().contains(&query))
        .cloned()
        .collect()
}

pub(crate) struct ComponentInput {
    pub(crate) state: gpui::Entity<InputState>,
    pub(crate) binding: SharedBinding<String>,
    pub(crate) submit_event: SharedEvent,
    pub(crate) focus_request: u64,
    pub(crate) placeholder: String,
    pub(crate) masked: bool,
    pub(crate) loading: bool,
    pub(crate) _subscription: gpui::Subscription,
}

pub(crate) struct ComponentSelect {
    pub(crate) state: gpui::Entity<SelectState<Vec<NativeSelectOption>>>,
    pub(crate) binding: SharedBinding<Option<String>>,
    pub(crate) options: Vec<NativeSelectOption>,
    pub(crate) _subscription: gpui::Subscription,
}

pub(crate) struct ComponentCombobox {
    pub(crate) state: gpui::Entity<ComboboxState<NativeComboboxDelegate>>,
    pub(crate) binding: SharedBinding<Option<String>>,
    pub(crate) search_event: SharedEvent,
    pub(crate) query: SharedQuery,
    pub(crate) options: Vec<NativeSelectOption>,
    pub(crate) _subscription: gpui::Subscription,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct SliderConfig {
    pub(crate) min: f32,
    pub(crate) max: f32,
    pub(crate) step: f32,
    pub(crate) logarithmic: bool,
}

impl SliderConfig {
    pub(crate) fn accepts(self, value: f32) -> bool {
        self.min.is_finite()
            && self.max.is_finite()
            && self.step.is_finite()
            && value.is_finite()
            && self.min < self.max
            && self.step > 0.0
            && value >= self.min
            && value <= self.max
            && (!self.logarithmic || self.min > 0.0)
    }
}

pub(crate) struct ComponentSlider {
    pub(crate) state: gpui::Entity<SliderState>,
    pub(crate) binding: SharedBinding<f64>,
    pub(crate) release_event: SharedEvent,
    pub(crate) config: SliderConfig,
    pub(crate) _subscription: gpui::Subscription,
}

#[derive(Clone)]
pub(crate) struct DialogConfig {
    pub(crate) title: String,
    pub(crate) width: f32,
    pub(crate) overlay: bool,
    pub(crate) closable: bool,
    pub(crate) keyboard: bool,
    pub(crate) close_button: bool,
    pub(crate) style: crate::StyleAttrs,
}

pub(crate) struct ComponentOverlayState {
    pub(crate) binding: SharedBinding<bool>,
    pub(crate) effective_open: Arc<Mutex<bool>>,
    pub(crate) trigger_focus: gpui::FocusHandle,
    pub(crate) content_focus: gpui::FocusHandle,
}

pub(crate) struct ComponentDialog {
    pub(crate) overlay: ComponentOverlayState,
    pub(crate) opened: Arc<Mutex<bool>>,
    pub(crate) keyboard: Arc<Mutex<bool>>,
    pub(crate) trigger_present: Arc<Mutex<bool>>,
    pub(crate) config: Arc<Mutex<DialogConfig>>,
    pub(crate) content: gpui::Entity<crate::ElixirRoot>,
    pub(crate) content_state: crate::SharedWindow,
}

pub(crate) struct ComponentPopover {
    pub(crate) overlay: ComponentOverlayState,
    pub(crate) previous_focus: Option<gpui::FocusHandle>,
    pub(crate) rendered_open: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct DropdownMenuItemConfig {
    pub(crate) value: String,
    pub(crate) label: String,
    pub(crate) disabled: bool,
    pub(crate) checked: bool,
}

pub(crate) struct ComponentDropdownMenu {
    pub(crate) overlay: ComponentOverlayState,
    pub(crate) menu: gpui::Entity<PopupMenu>,
    pub(crate) items: Vec<DropdownMenuItemConfig>,
    pub(crate) select_event: SharedEvent,
    pub(crate) rendered_open: bool,
}

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
struct ComponentKey {
    kind: ComponentKind,
    id: String,
}

impl ComponentKey {
    fn new(kind: ComponentKind, id: &str) -> Self {
        Self {
            kind,
            id: id.to_string(),
        }
    }
}

#[derive(Default)]
pub(crate) struct ComponentRegistry {
    entries: HashMap<ComponentKey, StatefulComponent>,
    active: HashSet<ComponentKey>,
}

#[cfg(feature = "components")]
include!("../generated/component_registry.rs");
#[cfg(not(feature = "components"))]
include!("../../../gpui_core/src/generated/component_registry.rs");

impl ComponentRegistry {
    pub(crate) fn editable_input_focused(&self, window: &gpui::Window, cx: &gpui::App) -> bool {
        use gpui::Focusable;

        self.entries.values().any(|component| match component {
            StatefulComponent::Input(input) => input.state.focus_handle(cx).is_focused(window),
            StatefulComponent::Combobox(combobox) => {
                combobox.state.focus_handle(cx).is_focused(window)
            }
            _component => false,
        })
    }

    pub(crate) fn begin_render(&mut self) {
        self.active.clear();
    }

    pub(crate) fn finish_render(&mut self, window: &mut gpui::Window, cx: &mut gpui::App) {
        use gpui_component::WindowExt;

        let mut close_dialog = false;
        for (key, component) in &self.entries {
            if !self.active.contains(key) {
                match component {
                    StatefulComponent::Dialog(dialog) => {
                        if let Ok(mut opened) = dialog.opened.lock() {
                            close_dialog |= *opened;
                            *opened = false;
                        }
                    }
                    StatefulComponent::DropTarget(target) => target.terminate_removed(),
                    _ => {}
                }
            }
        }
        self.entries
            .retain(|key, _component| self.active.contains(key));

        if close_dialog {
            window.defer(cx, |window, cx| window.close_dialog(cx));
        }
    }
}
