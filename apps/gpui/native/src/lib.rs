#![forbid(unsafe_code)]

pub mod image_decode;
pub mod raster;
pub mod resource;
pub mod transfer;
pub mod window_codec;

/// Stable identity for the application-owned core implementation crate.
pub const CRATE_ID: &str = "gpui_core";
