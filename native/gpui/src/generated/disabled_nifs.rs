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
    pub(crate) fn set_theme_impl<'a>(
        _env: Env<'a>,
        _runtime: ResourceArc<RuntimeResource>,
        _mode: Atom,
    ) -> NifResult<Term<'a>> {
        Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
    }
    pub(crate) fn put_resource_impl<'a>(
        _env: Env<'a>,
        _runtime: ResourceArc<RuntimeResource>,
        _resource_id: String,
        _resource: Term<'a>,
    ) -> NifResult<Term<'a>> {
        Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
    }
    pub(crate) fn drop_resource_impl<'a>(
        _env: Env<'a>,
        _runtime: ResourceArc<RuntimeResource>,
        _resource_id: String,
    ) -> NifResult<Term<'a>> {
        Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
    }
}
#[cfg(not(feature = "real-gpui"))]
pub(crate) use disabled_nifs::*;
