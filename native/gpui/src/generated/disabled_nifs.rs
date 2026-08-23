#[cfg(not(feature = "real-gpui"))]
mod disabled_nifs {
    use crate::*;
    pub(crate) fn open_window_impl<'a>(
        _env: Env<'a>,
        _runtime: ResourceArc<RuntimeResource>,
        _window: Term<'a>,
    ) -> NifResult<Term<'a>> {
        Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
    }
}
#[cfg(not(feature = "real-gpui"))]
pub(crate) use disabled_nifs::*;
