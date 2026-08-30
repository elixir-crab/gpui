#![forbid(unsafe_code)]

pub mod controlled;
pub mod host;
pub mod host_contract;
pub mod registry;

#[cfg(feature = "native-render")]
pub mod render;

/// Stable identity for the application-owned component implementation crate.
pub const CRATE_ID: &str = "gpui_components";

/// Proves the static component implementation depends on the core crate.
pub fn core_crate_id() -> &'static str {
    gpui_core::CRATE_ID
}
