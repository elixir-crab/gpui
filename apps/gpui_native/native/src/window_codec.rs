use crate::{Chrome, Lifecycle};

#[allow(dead_code)]
pub(crate) fn chrome_content() -> Chrome {
    Chrome::Content
}

#[allow(dead_code)]
pub(crate) fn lifecycle_close_request() -> Lifecycle {
    Lifecycle::CloseRequest
}

#[allow(dead_code)]
pub(crate) fn lifecycle_focus() -> Lifecycle {
    Lifecycle::Focus
}

#[allow(dead_code)]
pub(crate) fn lifecycle_blur() -> Lifecycle {
    Lifecycle::Blur
}
