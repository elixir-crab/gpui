use rustler::{NifResult, Term};

#[derive(Clone, Copy, Debug, Eq, PartialEq, rustler::NifUnitEnum)]
pub(crate) enum Theme {
    Light,
    Dark,
}

pub(crate) fn real_gpui_disabled<'a>() -> NifResult<Term<'a>> {
    Err(rustler::Error::Term(Box::new("real_gpui_disabled")))
}
