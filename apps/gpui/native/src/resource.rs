pub const MAX_RESOURCE_ID_BYTES: usize = 512;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ResourceRefError {
    UnsupportedType,
    InvalidId,
}

pub fn validate_raster_ref(resource_type: &str, id: &str) -> Result<(), ResourceRefError> {
    if resource_type != "raster" {
        return Err(ResourceRefError::UnsupportedType);
    }
    if id.is_empty() || id.len() > MAX_RESOURCE_ID_BYTES || id.chars().any(char::is_control) {
        return Err(ResourceRefError::InvalidId);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_bounded_raster_references() {
        assert_eq!(validate_raster_ref("raster", "logo"), Ok(()));
    }

    #[test]
    fn rejects_unknown_types_and_invalid_ids() {
        assert_eq!(
            validate_raster_ref("font", "logo"),
            Err(ResourceRefError::UnsupportedType)
        );
        assert_eq!(
            validate_raster_ref("raster", ""),
            Err(ResourceRefError::InvalidId)
        );
        assert_eq!(
            validate_raster_ref("raster", "bad\nid"),
            Err(ResourceRefError::InvalidId)
        );
    }
}
