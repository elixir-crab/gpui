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

    if resource.resource_type != "raster" {
        return Err(rustler::Error::Term(Box::new("unsupported_resource_type")));
    }

    Ok(resource.id)
}

impl RasterData {
    pub(crate) fn validate(&self) -> NifResult<()> {
        if self.width == 0 || self.height == 0 {
            return Err(rustler::Error::Term(Box::new("invalid_raster_dimensions")));
        }

        if self.format != "rgba8" && self.format != "bgra8" {
            return Err(rustler::Error::Term(Box::new("unsupported_raster_format")));
        }

        let row_bytes = (self.width as usize)
            .checked_mul(4)
            .ok_or_else(|| rustler::Error::Term(Box::new("raster_size_overflow")))?;
        let stride = self
            .stride
            .map(|stride| stride as usize)
            .unwrap_or(row_bytes);

        if stride < row_bytes {
            return Err(rustler::Error::Term(Box::new("invalid_raster_stride")));
        }

        let expected_len = (self.height as usize - 1)
            .checked_mul(stride)
            .and_then(|length| length.checked_add(row_bytes))
            .ok_or_else(|| rustler::Error::Term(Box::new("raster_size_overflow")))?;
        if self.data.len() < expected_len {
            return Err(rustler::Error::Term(Box::new("invalid_raster_data")));
        }

        Ok(())
    }

    pub(crate) fn render(self) -> gpui::AnyElement {
        use gpui::{img, IntoElement, RenderImage};
        use image::{Frame, RgbaImage};

        let width = self.width;
        let height = self.height;
        let data = self.into_rgba();
        let image =
            RgbaImage::from_raw(width, height, data).unwrap_or_else(|| RgbaImage::new(1, 1));
        let render_image = Arc::new(RenderImage::new(vec![Frame::new(image)]));

        img(render_image).into_any_element()
    }

    fn into_rgba(mut self) -> Vec<u8> {
        let Some(row_bytes) = (self.width as usize).checked_mul(4) else {
            return Vec::new();
        };
        let Some(packed_len) = row_bytes.checked_mul(self.height as usize) else {
            return Vec::new();
        };

        if let Some(stride) = self.stride.map(|stride| stride as usize) {
            if stride != row_bytes {
                let mut compact = Vec::with_capacity(packed_len);
                for row in 0..self.height as usize {
                    let Some(start) = row.checked_mul(stride) else {
                        return Vec::new();
                    };
                    let Some(end) = start.checked_add(row_bytes) else {
                        return Vec::new();
                    };
                    let Some(row_data) = self.data.get(start..end) else {
                        return Vec::new();
                    };
                    compact.extend_from_slice(row_data);
                }
                self.data = compact;
            }
        }

        self.data.truncate(packed_len);

        if self.format == "bgra8" {
            for pixel in self.data.chunks_exact_mut(4) {
                pixel.swap(0, 2);
            }
        }

        self.data
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compacts_stride_and_converts_bgra_to_rgba() {
        let raster = RasterData {
            width: 1,
            height: 2,
            format: "bgra8".to_string(),
            stride: Some(8),
            data: vec![3, 2, 1, 255, 9, 9, 9, 9, 6, 5, 4, 255, 8, 8, 8, 8],
        };

        assert_eq!(raster.into_rgba(), vec![1, 2, 3, 255, 4, 5, 6, 255]);
    }

    #[test]
    fn rejects_raster_size_overflow_without_panicking() {
        let raster = RasterData {
            width: u32::MAX,
            height: u32::MAX,
            format: "rgba8".to_string(),
            stride: Some(u32::MAX),
            data: Vec::new(),
        };

        assert!(raster.validate().is_err());
        assert!(raster.into_rgba().is_empty());
    }

    #[test]
    fn truncates_trailing_bytes_from_packed_rasters() {
        let raster = RasterData {
            width: 1,
            height: 1,
            format: "rgba8".to_string(),
            stride: None,
            data: vec![1, 2, 3, 255, 9, 9],
        };

        assert_eq!(raster.into_rgba(), vec![1, 2, 3, 255]);
    }
}
