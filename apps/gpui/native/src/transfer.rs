use std::collections::HashSet;
use std::path::Path;

pub const MAX_TRANSFER_TEXT_BYTES: usize = 1_048_576;
pub const MAX_PATHS: usize = 64;
pub const MAX_PATH_BYTES: usize = 4_096;
pub const MAX_ALL_PATH_BYTES: usize = 262_144;

pub fn bounded_text(text: Option<String>) -> Option<String> {
    text.filter(|text| !text.is_empty() && text.len() <= MAX_TRANSFER_TEXT_BYTES)
}

pub fn bounded_path_strings<'a>(paths: impl IntoIterator<Item = &'a Path>) -> Option<Vec<String>> {
    let mut result = Vec::new();
    let mut seen = HashSet::new();
    let mut total = 0usize;

    for path in paths {
        if result.len() >= MAX_PATHS {
            return None;
        }
        let path = path.to_str()?;
        let bytes = path.len();
        if path.is_empty()
            || bytes > MAX_PATH_BYTES
            || total.checked_add(bytes)? > MAX_ALL_PATH_BYTES
        {
            return None;
        }
        if seen.insert(path) {
            total += bytes;
            result.push(path.to_owned());
        }
    }

    Some(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounds_transfer_text() {
        assert_eq!(bounded_text(Some("hello".into())), Some("hello".into()));
        assert_eq!(bounded_text(Some(String::new())), None);
        assert_eq!(
            bounded_text(Some("x".repeat(MAX_TRANSFER_TEXT_BYTES + 1))),
            None
        );
    }

    #[test]
    fn deduplicates_bounded_paths() {
        let paths = [
            Path::new("/tmp/a"),
            Path::new("/tmp/a"),
            Path::new("/tmp/b"),
        ];
        assert_eq!(
            bounded_path_strings(paths),
            Some(vec!["/tmp/a".into(), "/tmp/b".into()])
        );
    }
}
