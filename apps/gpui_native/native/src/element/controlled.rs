#![cfg_attr(not(feature = "components"), allow(dead_code))]

use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
};

pub(crate) struct ControlledBinding<T> {
    pub(crate) event: Option<String>,
    confirmed_value: T,
    pending_values: VecDeque<T>,
}

impl<T> ControlledBinding<T>
where
    T: Clone + PartialEq,
{
    pub(crate) fn new(event: Option<String>, value: T) -> Self {
        Self {
            event,
            confirmed_value: value,
            pending_values: VecDeque::new(),
        }
    }

    pub(crate) fn push_pending(&mut self, value: T) {
        self.pending_values.push_back(value);
    }

    pub(crate) fn pop_pending(&mut self) {
        self.pending_values.pop_back();
    }

    pub(crate) fn reconcile(&mut self, value: &T) -> bool {
        if let Some(index) = self
            .pending_values
            .iter()
            .position(|pending| pending == value)
        {
            self.pending_values.drain(..=index);
            self.confirmed_value = value.clone();
            return false;
        }

        if !self.pending_values.is_empty() && value == &self.confirmed_value {
            return false;
        }

        self.pending_values.clear();
        self.confirmed_value = value.clone();
        true
    }
}

pub(crate) type SharedBinding<T> = Arc<Mutex<ControlledBinding<T>>>;

#[cfg(test)]
mod tests {
    use super::ControlledBinding;

    #[test]
    fn ignores_stale_snapshots_until_local_edits_are_confirmed() {
        let mut binding = ControlledBinding::new(Some("change".to_string()), String::new());
        binding.push_pending("a".to_string());
        binding.push_pending("ab".to_string());

        assert!(!binding.reconcile(&String::new()));
        assert!(!binding.reconcile(&"a".to_string()));
        assert!(!binding.reconcile(&"ab".to_string()));
        assert!(binding.reconcile(&"server".to_string()));
    }
}
