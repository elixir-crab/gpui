const MAX_ENCODED_BYTES: usize = 100 * 1_024 * 1_024;
const MAX_IMAGE_DIMENSION: u32 = 16_384;
const MAX_DECODED_BYTES: u64 = 256 * 1_024 * 1_024;

pub fn decode(bytes: &[u8]) -> Result<(u32, u32, Vec<u8>), image::ImageError> {
    use image::{error::LimitError, error::LimitErrorKind, ImageError, ImageReader, Limits};
    use std::io::Cursor;

    if bytes.len() > MAX_ENCODED_BYTES {
        return Err(ImageError::Limits(LimitError::from_kind(
            LimitErrorKind::InsufficientMemory,
        )));
    }

    let mut reader = ImageReader::new(Cursor::new(bytes)).with_guessed_format()?;
    let mut limits = Limits::default();
    limits.max_image_width = Some(MAX_IMAGE_DIMENSION);
    limits.max_image_height = Some(MAX_IMAGE_DIMENSION);
    limits.max_alloc = Some(MAX_DECODED_BYTES);
    reader.limits(limits);

    let image = reader.decode()?.into_rgba8();
    let width = image.width();
    let height = image.height();
    Ok((width, height, image.into_raw()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_invalid_image_bytes() {
        assert!(decode(b"not an image").is_err());
    }

    #[test]
    fn rejects_images_beyond_the_dimension_limit() {
        use image::{DynamicImage, ImageFormat, RgbaImage};
        use std::io::Cursor;

        let image = RgbaImage::new(MAX_IMAGE_DIMENSION + 1, 1);
        let mut encoded = Cursor::new(Vec::new());
        DynamicImage::ImageRgba8(image)
            .write_to(&mut encoded, ImageFormat::Bmp)
            .expect("test image should encode");

        assert!(decode(encoded.get_ref()).is_err());
    }
}
