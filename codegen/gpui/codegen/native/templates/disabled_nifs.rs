#[cfg(not(feature = "real-gpui"))]
mod disabled_nifs {
    use crate::*;

    __rq_items!();
}

#[cfg(not(feature = "real-gpui"))]
pub(crate) use disabled_nifs::*;
