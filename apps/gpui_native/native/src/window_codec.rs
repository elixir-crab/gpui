use crate::{Chrome, Lifecycle};

pub(crate) fn chrome_content() -> Chrome {
    Chrome::Content
}

pub(crate) fn lifecycle_close_request() -> Lifecycle {
    Lifecycle::CloseRequest
}

pub(crate) fn lifecycle_focus() -> Lifecycle {
    Lifecycle::Focus
}

pub(crate) fn lifecycle_blur() -> Lifecycle {
    Lifecycle::Blur
}
