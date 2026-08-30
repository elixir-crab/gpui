#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Raster {
    pub width: u32,
    pub height: u32,
    pub format: String,
    pub stride: Option<u32>,
    pub data: Vec<u8>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RasterError {
    InvalidDimensions,
    UnsupportedFormat,
    SizeOverflow,
    InvalidStride,
    InvalidData,
}

impl Raster {
    pub fn validate(&self) -> Result<(), RasterError> {
        if self.width == 0 || self.height == 0 {
            return Err(RasterError::InvalidDimensions);
        }
        if self.format != "rgba8" && self.format != "bgra8" {
            return Err(RasterError::UnsupportedFormat);
        }

        let row_bytes = (self.width as usize)
            .checked_mul(4)
            .ok_or(RasterError::SizeOverflow)?;
        let stride = self.stride.map(|value| value as usize).unwrap_or(row_bytes);
        if stride < row_bytes {
            return Err(RasterError::InvalidStride);
        }

        let expected_len = (self.height as usize - 1)
            .checked_mul(stride)
            .and_then(|length| length.checked_add(row_bytes))
            .ok_or(RasterError::SizeOverflow)?;
        if self.data.len() < expected_len {
            return Err(RasterError::InvalidData);
        }

        Ok(())
    }

    pub fn into_rgba(mut self) -> Result<Vec<u8>, RasterError> {
        self.validate()?;
        let row_bytes = (self.width as usize)
            .checked_mul(4)
            .ok_or(RasterError::SizeOverflow)?;
        let packed_len = row_bytes
            .checked_mul(self.height as usize)
            .ok_or(RasterError::SizeOverflow)?;

        if let Some(stride) = self.stride.map(|value| value as usize) {
            if stride != row_bytes {
                let mut compact = Vec::with_capacity(packed_len);
                for row in 0..self.height as usize {
                    let start = row.checked_mul(stride).ok_or(RasterError::SizeOverflow)?;
                    let end = start
                        .checked_add(row_bytes)
                        .ok_or(RasterError::SizeOverflow)?;
                    let row_data = self.data.get(start..end).ok_or(RasterError::InvalidData)?;
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
        Ok(self.data)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compacts_stride_and_converts_bgra_to_rgba() {
        let raster = Raster {
            width: 1,
            height: 2,
            format: "bgra8".into(),
            stride: Some(8),
            data: vec![3, 2, 1, 255, 9, 9, 9, 9, 6, 5, 4, 255, 8, 8, 8, 8],
        };
        assert_eq!(
            raster.into_rgba().unwrap(),
            vec![1, 2, 3, 255, 4, 5, 6, 255]
        );
    }

    #[test]
    fn rejects_size_overflow_without_panicking() {
        let raster = Raster {
            width: u32::MAX,
            height: u32::MAX,
            format: "rgba8".into(),
            stride: Some(u32::MAX),
            data: Vec::new(),
        };
        assert_eq!(raster.validate(), Err(RasterError::InvalidStride));
        assert!(raster.into_rgba().is_err());
    }

    #[test]
    fn truncates_trailing_bytes() {
        let raster = Raster {
            width: 1,
            height: 1,
            format: "rgba8".into(),
            stride: None,
            data: vec![1, 2, 3, 255, 9, 9],
        };
        assert_eq!(raster.into_rgba().unwrap(), vec![1, 2, 3, 255]);
    }
}
