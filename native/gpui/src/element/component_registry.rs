use super::controlled::SharedBinding;
use crate::gpui;
use gpui_component::{input::InputState, searchable_list::SearchableListItem, select::SelectState};
use std::{
    collections::{HashMap, HashSet},
    hash::Hash,
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

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
enum ComponentKind {
    Input,
    Select,
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
    Select(ComponentSelect),
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
}
