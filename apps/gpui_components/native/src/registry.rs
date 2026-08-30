use std::collections::HashSet;

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub struct ComponentKey {
    pub kind: &'static str,
    pub id: String,
}

impl ComponentKey {
    pub fn new(kind: &'static str, id: &str) -> Self {
        Self {
            kind,
            id: id.to_owned(),
        }
    }
}

#[derive(Default)]
pub struct ActiveComponents {
    active: HashSet<ComponentKey>,
}

impl ActiveComponents {
    pub fn begin_render(&mut self) {
        self.active.clear();
    }
    pub fn activate(&mut self, kind: &'static str, id: &str) -> ComponentKey {
        let key = ComponentKey::new(kind, id);
        self.active.insert(key.clone());
        key
    }
    pub fn contains(&self, key: &ComponentKey) -> bool {
        self.active.contains(key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn render_activity_is_scoped_to_each_frame() {
        let mut active = ActiveComponents::default();
        let key = active.activate("input", "name");
        assert!(active.contains(&key));
        active.begin_render();
        assert!(!active.contains(&key));
    }
}
