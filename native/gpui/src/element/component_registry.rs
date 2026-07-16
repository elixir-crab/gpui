use super::controlled::SharedBinding;
use crate::{gpui, push_event, EventValue, InputKind, NativeEvent, SharedRuntime};
use gpui_component::{
    combobox::ComboboxState,
    input::InputState,
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

pub(crate) struct ComponentPopover {
    pub(crate) binding: SharedBinding<bool>,
    pub(crate) effective_open: Arc<Mutex<bool>>,
    pub(crate) trigger_focus: gpui::FocusHandle,
    pub(crate) content_focus: gpui::FocusHandle,
    pub(crate) previous_focus: Option<gpui::FocusHandle>,
    pub(crate) rendered_open: bool,
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
enum ComponentKind {
    Input,
    Popover,
    Select,
    Combobox,
    Slider,
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

enum StatefulComponent {
    Input(ComponentInput),
    Popover(ComponentPopover),
    Select(ComponentSelect),
    Combobox(ComponentCombobox),
    Slider(ComponentSlider),
}

#[derive(Default)]
pub(crate) struct ComponentRegistry {
    entries: HashMap<ComponentKey, StatefulComponent>,
    active: HashSet<ComponentKey>,
}

impl ComponentRegistry {
    pub(crate) fn begin_render(&mut self) {
        self.active.clear();
    }

    pub(crate) fn finish_render(&mut self) {
        self.entries
            .retain(|key, _component| self.active.contains(key));
    }

    pub(crate) fn input_mut(&mut self, id: &str) -> Option<&mut ComponentInput> {
        let key = ComponentKey::new(ComponentKind::Input, id);
        self.active.insert(key.clone());
        match self.entries.get_mut(&key) {
            Some(StatefulComponent::Input(input)) => Some(input),
            _other => None,
        }
    }

    pub(crate) fn insert_input(&mut self, id: &str, input: ComponentInput) {
        let key = ComponentKey::new(ComponentKind::Input, id);
        self.active.insert(key.clone());
        self.entries.insert(key, StatefulComponent::Input(input));
    }

    pub(crate) fn popover_mut(&mut self, id: &str) -> Option<&mut ComponentPopover> {
        let key = ComponentKey::new(ComponentKind::Popover, id);
        self.active.insert(key.clone());
        match self.entries.get_mut(&key) {
            Some(StatefulComponent::Popover(popover)) => Some(popover),
            _other => None,
        }
    }

    pub(crate) fn insert_popover(&mut self, id: &str, popover: ComponentPopover) {
        let key = ComponentKey::new(ComponentKind::Popover, id);
        self.active.insert(key.clone());
        self.entries
            .insert(key, StatefulComponent::Popover(popover));
    }

    pub(crate) fn select_mut(&mut self, id: &str) -> Option<&mut ComponentSelect> {
        let key = ComponentKey::new(ComponentKind::Select, id);
        self.active.insert(key.clone());
        match self.entries.get_mut(&key) {
            Some(StatefulComponent::Select(select)) => Some(select),
            _other => None,
        }
    }

    pub(crate) fn insert_select(&mut self, id: &str, select: ComponentSelect) {
        let key = ComponentKey::new(ComponentKind::Select, id);
        self.active.insert(key.clone());
        self.entries.insert(key, StatefulComponent::Select(select));
    }

    pub(crate) fn combobox_mut(&mut self, id: &str) -> Option<&mut ComponentCombobox> {
        let key = ComponentKey::new(ComponentKind::Combobox, id);
        self.active.insert(key.clone());
        match self.entries.get_mut(&key) {
            Some(StatefulComponent::Combobox(combobox)) => Some(combobox),
            _other => None,
        }
    }

    pub(crate) fn insert_combobox(&mut self, id: &str, combobox: ComponentCombobox) {
        let key = ComponentKey::new(ComponentKind::Combobox, id);
        self.active.insert(key.clone());
        self.entries
            .insert(key, StatefulComponent::Combobox(combobox));
    }

    pub(crate) fn slider_mut(&mut self, id: &str) -> Option<&mut ComponentSlider> {
        let key = ComponentKey::new(ComponentKind::Slider, id);
        self.active.insert(key.clone());
        match self.entries.get_mut(&key) {
            Some(StatefulComponent::Slider(slider)) => Some(slider),
            _other => None,
        }
    }

    pub(crate) fn insert_slider(&mut self, id: &str, slider: ComponentSlider) {
        let key = ComponentKey::new(ComponentKind::Slider, id);
        self.active.insert(key.clone());
        self.entries.insert(key, StatefulComponent::Slider(slider));
    }
}
