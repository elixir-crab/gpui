#![forbid(unsafe_code)]

pub mod image_decode;
pub mod raster;
#[cfg(feature = "native-render")]
pub mod render;
pub mod resource;
#[cfg(feature = "native-render")]
pub mod style;
#[cfg(feature = "native-render")]
pub mod style_wire;
pub mod text;
pub mod transfer;
pub mod window_codec;

include!("generated/style.rs");

mod generated_schema {
    #![allow(unexpected_cfgs)]
    include!("generated/schema.rs");
}

#[cfg(any())]
mod generated_registry {
    include!("generated/component_registry.rs");
}

pub use generated_schema::{
    decode_generated_element_tag, generated_component_kind, GeneratedComponentKind,
    GeneratedElementTag,
};

/// Stable identity for the application-owned core implementation crate.
pub const CRATE_ID: &str = "gpui_core";

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compiles_the_generated_vanilla_protocol_identity() {
        let tag = decode_generated_element_tag("div");
        assert_eq!(tag, GeneratedElementTag::Div);
        assert_eq!(
            generated_component_kind(tag),
            GeneratedComponentKind::Container
        );
    }
}
