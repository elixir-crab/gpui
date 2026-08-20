#[cfg(test)]
use crate::gpui;

#[cfg(test)]
pub(crate) struct NativeTestHarness<'a> {
    pub(crate) runtime: crate::SharedRuntime,
    pub(crate) cx: &'a mut gpui::VisualTestContext,
}

#[cfg(test)]
impl<'a> NativeTestHarness<'a> {
    pub(crate) fn new(
        cx: &'a mut gpui::TestAppContext,
        tree: crate::ElementNode,
        size: gpui::Size<gpui::Pixels>,
    ) -> Self {
        use gpui::IntoElement as _;

        cx.update(gpui_component::init);

        let runtime = std::sync::Arc::new(crate::runtime::RuntimeState::new());
        let state = std::sync::Arc::new(crate::WindowState::new(tree, Vec::new()));
        let runtime_for_view = runtime.clone();
        let state_for_view = state.clone();
        let (view, cx) = cx.add_window_view(move |_window, _cx| {
            crate::ElixirRoot::new(state_for_view, runtime_for_view, 7, false, false)
        });

        cx.draw(gpui::Point::default(), size, |_window, _cx| {
            view.clone().into_any_element()
        });

        Self { runtime, cx }
    }

    pub(crate) fn click(&mut self, position: gpui::Point<gpui::Pixels>) {
        self.cx.simulate_click(position, gpui::Modifiers::default());
    }

    pub(crate) fn click_element(&mut self, id: &'static str) {
        let bounds = self.element_bounds(id);
        self.click(bounds.center());
    }

    pub(crate) fn click_element_at(&mut self, id: &'static str, offset: gpui::Point<gpui::Pixels>) {
        let bounds = self.element_bounds(id);
        self.click(bounds.origin + offset);
    }

    pub(crate) fn simulate_keystrokes(&mut self, keystrokes: &str) {
        self.cx.simulate_keystrokes(keystrokes);
    }

    fn element_bounds(&mut self, id: &'static str) -> gpui::Bounds<gpui::Pixels> {
        self.cx
            .debug_bounds(id)
            .unwrap_or_else(|| panic!("missing rendered element {id:?}"))
    }

    pub(crate) fn take_events(&self) -> Vec<crate::NativeEvent> {
        std::mem::take(&mut *self.runtime.events.lock().expect("native test events"))
    }
}
