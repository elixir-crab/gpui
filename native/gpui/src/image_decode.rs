pub(crate) fn decode(bytes: &[u8]) -> Result<(u32, u32, Vec<u8>), image::ImageError> {
    let image = image::load_from_memory(bytes)?.into_rgba8();
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
}
