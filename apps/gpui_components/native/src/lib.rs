#![forbid(unsafe_code)]

include!("generated/nodes.rs");

pub mod controlled;
pub mod controls;
pub mod host;
pub mod host_contract;
#[cfg(feature = "native-render")]
pub mod radio;
pub mod registry;
#[cfg(feature = "native-render")]
pub mod rendered_control;

#[cfg(feature = "native-render")]
pub mod render;
#[cfg(feature = "native-render")]
pub mod slider;
#[cfg(feature = "native-render")]
pub mod style;
#[cfg(feature = "native-render")]
pub mod switch;

/// Stable identity for the application-owned component implementation crate.
pub const CRATE_ID: &str = "gpui_components";

/// Proves the static component implementation depends on the core crate.
pub fn core_crate_id() -> &'static str {
    gpui_core::CRATE_ID
}
