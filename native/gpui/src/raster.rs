use crate::{gpui, GeneratedRaster};
use rustler::NifResult;
use std::sync::Arc;

#[derive(Clone, Debug)]
pub(crate) enum ImageData {
    Raster(RasterData),
    Ref(String),
}

#[derive(Clone, Debug, Default)]
pub(crate) struct RasterData {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) format: String,
    pub(crate) stride: Option<u32>,
    pub(crate) data: Vec<u8>,
}

impl From<GeneratedRaster> for RasterData {
    fn from(raster: GeneratedRaster) -> Self {
        Self {
            width: raster.width,
            height: raster.height,
            format: raster.format,
            stride: raster.stride,
            data: raster.data,
        }
    }
}

impl RasterData {
    pub(crate) fn validate(&self) -> NifResult<()> {
        if self.width == 0 || self.height == 0 {
            return Err(rustler::Error::Term(Box::new("invalid_raster_dimensions")));
        }

        if self.format != "rgba8" && self.format != "bgra8" {
            return Err(rustler::Error::Term(Box::new("unsupported_raster_format")));
        }

        let row_bytes = self.width as usize * 4;
        let stride = self
            .stride
            .map(|stride| stride as usize)
            .unwrap_or(row_bytes);

        if stride < row_bytes {
            return Err(rustler::Error::Term(Box::new("invalid_raster_stride")));
        }

        let expected_len = stride * (self.height as usize - 1) + row_bytes;
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
        let row_bytes = self.width as usize * 4;

        if let Some(stride) = self.stride.map(|stride| stride as usize) {
            if stride != row_bytes {
                let mut compact = Vec::with_capacity(row_bytes * self.height as usize);
                for row in 0..self.height as usize {
                    let start = row * stride;
                    compact.extend_from_slice(&self.data[start..start + row_bytes]);
                }
                self.data = compact;
            }
        }

        if self.format == "bgra8" {
            for pixel in self.data.chunks_exact_mut(4) {
                pixel.swap(0, 2);
            }
        }

        self.data
    }
}
