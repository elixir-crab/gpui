use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

pub struct ControlledBinding<T> {
    pub event: Option<String>,
    confirmed_value: T,
    pending_values: VecDeque<T>,
}

impl<T> ControlledBinding<T>
where
    T: Clone + PartialEq,
{
    pub fn new(event: Option<String>, value: T) -> Self {
        Self {
            event,
            confirmed_value: value,
            pending_values: VecDeque::new(),
        }
    }

    pub fn push_pending(&mut self, value: T) {
        self.pending_values.push_back(value);
    }
    pub fn pop_pending(&mut self) {
        self.pending_values.pop_back();
    }

    pub fn reconcile(&mut self, value: &T) -> bool {
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

pub type SharedBinding<T> = Arc<Mutex<ControlledBinding<T>>>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ignores_stale_snapshots_until_local_edits_are_confirmed() {
        let mut binding = ControlledBinding::new(Some("change".into()), String::new());
        binding.push_pending("a".into());
        binding.push_pending("ab".into());
        assert!(!binding.reconcile(&String::new()));
        assert!(!binding.reconcile(&"a".into()));
        assert!(!binding.reconcile(&"ab".into()));
        assert!(binding.reconcile(&"server".into()));
    }
}
