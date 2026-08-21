use rustler::{NifResult, Term};

pub(crate) fn real_gpui_disabled<'a>() -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
}
