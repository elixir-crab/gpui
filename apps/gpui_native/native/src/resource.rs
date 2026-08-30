use crate::{atoms, gpui};
use rustler::{Binary, NifResult, Term};
use std::sync::Arc;

include!("generated/resources.rs");

#[derive(Clone, Debug)]
pub(crate) enum ImageData {
    Raster(RasterData),
    Ref(String),
}

pub(crate) fn decode_resource_ref(term: Term) -> NifResult<String> {
    let resource = decode_resource_ref_data(term)?;

    gpui_core::resource::validate_raster_ref(&resource.resource_type, &resource.id)
        .map_err(resource_ref_error)?;

    Ok(resource.id)
}

fn resource_ref_error(error: gpui_core::resource::ResourceRefError) -> rustler::Error {
    use gpui_core::resource::ResourceRefError;

    let reason = match error {
        ResourceRefError::UnsupportedType => "unsupported_resource_type",
        ResourceRefError::InvalidId => "invalid_resource_id",
    };
    rustler::Error::Term(Box::new(reason))
}

impl RasterData {
    fn core_raster(self) -> gpui_core::raster::Raster {
        gpui_core::raster::Raster {
            width: self.width,
            height: self.height,
            format: self.format,
            stride: self.stride,
            data: self.data,
        }
    }

    pub(crate) fn validate(&self) -> NifResult<()> {
        gpui_core::raster::Raster {
            width: self.width,
            height: self.height,
            format: self.format.clone(),
            stride: self.stride,
            data: self.data.clone(),
        }
        .validate()
        .map_err(raster_error)
    }

    pub(crate) fn render(self) -> gpui::AnyElement {
        use gpui::{img, IntoElement, RenderImage};
        use image::{Frame, RgbaImage};

        let width = self.width;
        let height = self.height;
        let data = self.core_raster().into_rgba().unwrap_or_default();
        let image =
            RgbaImage::from_raw(width, height, data).unwrap_or_else(|| RgbaImage::new(1, 1));
        let render_image = Arc::new(RenderImage::new(vec![Frame::new(image)]));

        img(render_image).into_any_element()
    }
}

fn raster_error(error: gpui_core::raster::RasterError) -> rustler::Error {
    use gpui_core::raster::RasterError;

    let reason = match error {
        RasterError::InvalidDimensions => "invalid_raster_dimensions",
        RasterError::UnsupportedFormat => "unsupported_raster_format",
        RasterError::SizeOverflow => "raster_size_overflow",
        RasterError::InvalidStride => "invalid_raster_stride",
        RasterError::InvalidData => "invalid_raster_data",
    };
    rustler::Error::Term(Box::new(reason))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_core_validation_errors_to_nif_errors() {
        let raster = RasterData {
            width: 0,
            height: 1,
            format: "rgba8".to_string(),
            stride: None,
            data: Vec::new(),
        };

        assert!(raster.validate().is_err());
    }
}
