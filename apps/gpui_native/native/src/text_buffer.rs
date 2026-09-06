#[cfg(feature = "components")]
use crate::TextEdit;
use crate::{
    TextPosition, TextRange, TextSelection, TextSnapshot, TextTransaction, TransactionResult,
};
use gpui_core::text as core;
#[cfg(feature = "components")]
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

#[cfg(feature = "components")]
static NEXT_NATIVE_TRANSACTION_ID: AtomicU64 = AtomicU64::new(1);
#[cfg(feature = "components")]
pub(crate) fn next_native_transaction_id(surface_id: &str) -> String {
    let sequence = NEXT_NATIVE_TRANSACTION_ID.fetch_add(1, Ordering::Relaxed);
    format!("native-{surface_id}-{sequence}")
}

pub(crate) struct TextBufferResource {
    state: Mutex<core::Buffer>,
}
#[rustler::resource_impl]
impl rustler::Resource for TextBufferResource {}

#[derive(Debug, PartialEq, Eq)]
pub(crate) enum TextBufferError {
    InvalidPosition,
    InvalidRange,
    InvalidSelection,
    OverlappingEdits,
    StaleRevision(u64),
    TransactionConflict,
    NothingToUndo,
    NothingToRedo,
    #[cfg(feature = "components")]
    NoChange,
    LockFailed,
}

impl TextBufferResource {
    pub(crate) fn new(
        text: String,
        revision: u64,
        selections: Vec<TextSelection>,
    ) -> Result<Self, TextBufferError> {
        Ok(Self {
            state: Mutex::new(
                core::Buffer::new(
                    text,
                    revision,
                    selections.into_iter().map(to_core_selection).collect(),
                )
                .map_err(map_error)?,
            ),
        })
    }
    #[cfg(feature = "components")]
    pub(crate) fn revision(&self) -> Result<u64, TextBufferError> {
        Ok(self
            .state
            .lock()
            .map_err(|_| TextBufferError::LockFailed)?
            .revision())
    }
    pub(crate) fn snapshot(&self) -> Result<TextSnapshot, TextBufferError> {
        Ok(from_core_snapshot(
            self.state
                .lock()
                .map_err(|_| TextBufferError::LockFailed)?
                .snapshot(),
        ))
    }
    pub(crate) fn transact(
        &self,
        transaction: TextTransaction,
    ) -> Result<TransactionResult, TextBufferError> {
        Ok(from_core_result(
            self.state
                .lock()
                .map_err(|_| TextBufferError::LockFailed)?
                .transact(to_core_transaction(transaction))
                .map_err(map_error)?,
        ))
    }
    pub(crate) fn undo(&self, revision: u64) -> Result<TextSnapshot, TextBufferError> {
        Ok(from_core_snapshot(
            self.state
                .lock()
                .map_err(|_| TextBufferError::LockFailed)?
                .undo(revision)
                .map_err(map_error)?,
        ))
    }
    pub(crate) fn redo(&self, revision: u64) -> Result<TextSnapshot, TextBufferError> {
        Ok(from_core_snapshot(
            self.state
                .lock()
                .map_err(|_| TextBufferError::LockFailed)?
                .redo(revision)
                .map_err(map_error)?,
        ))
    }
    #[cfg(feature = "components")]
    pub(crate) fn replace_from_surface(
        &self,
        revision: u64,
        id: String,
        text: String,
        selection: TextSelection,
    ) -> Result<(TextTransaction, u64), TextBufferError> {
        let (transaction, revision) = self
            .state
            .lock()
            .map_err(|_| TextBufferError::LockFailed)?
            .replace_from_surface(revision, id, text, to_core_selection(selection))
            .map_err(map_error)?;
        Ok((from_core_transaction(transaction), revision))
    }
    #[cfg(feature = "components")]
    pub(crate) fn update_selection_from_surface(
        &self,
        revision: u64,
        selection: TextSelection,
    ) -> Result<u64, TextBufferError> {
        self.state
            .lock()
            .map_err(|_| TextBufferError::LockFailed)?
            .update_selection_from_surface(revision, to_core_selection(selection))
            .map_err(map_error)
    }
}

include!("generated/text_conversions.rs");

#[cfg(feature = "components")]
fn no_change_error() -> TextBufferError {
    TextBufferError::NoChange
}

#[cfg(not(feature = "components"))]
fn no_change_error() -> TextBufferError {
    TextBufferError::TransactionConflict
}

#[cfg(any(test, feature = "components"))]
pub(crate) fn position_to_byte_offset(
    text: &str,
    position: &TextPosition,
) -> Result<usize, TextBufferError> {
    core::position_to_byte_offset(text, &to_core_position(position.clone())).map_err(map_error)
}
#[cfg(any(test, feature = "components"))]
pub(crate) fn range_to_byte_range(
    text: &str,
    range: &TextRange,
) -> Result<std::ops::Range<usize>, TextBufferError> {
    core::range_to_byte_range(text, &to_core_range(range.clone())).map_err(map_error)
}
#[cfg(any(test, feature = "components"))]
pub(crate) fn selection_to_byte_range(
    text: &str,
    selection: &TextSelection,
) -> Result<std::ops::Range<usize>, TextBufferError> {
    core::selection_to_byte_range(text, &to_core_selection(selection.clone())).map_err(map_error)
}
#[cfg(any(test, feature = "components"))]
pub(crate) fn byte_range_to_selection(
    text: &str,
    range: std::ops::Range<usize>,
) -> Result<TextSelection, TextBufferError> {
    core::byte_range_to_selection(text, range)
        .map(from_core_selection)
        .map_err(map_error)
}

#[cfg(test)]
mod conversion_tests {
    use super::*;

    #[test]
    fn core_errors_preserve_boundary_variants() {
        let cases = [
            (
                core::Error::InvalidPosition,
                TextBufferError::InvalidPosition,
            ),
            (core::Error::InvalidRange, TextBufferError::InvalidRange),
            (
                core::Error::InvalidSelection,
                TextBufferError::InvalidSelection,
            ),
            (
                core::Error::OverlappingEdits,
                TextBufferError::OverlappingEdits,
            ),
            (
                core::Error::TransactionConflict,
                TextBufferError::TransactionConflict,
            ),
            (core::Error::NothingToUndo, TextBufferError::NothingToUndo),
            (core::Error::NothingToRedo, TextBufferError::NothingToRedo),
            (
                core::Error::StaleRevision(u64::MAX),
                TextBufferError::StaleRevision(u64::MAX),
            ),
        ];
        for (source, expected) in cases {
            assert_eq!(map_error(source), expected);
        }
        #[cfg(feature = "components")]
        assert_eq!(map_error(core::Error::NoChange), TextBufferError::NoChange);
        #[cfg(not(feature = "components"))]
        assert_eq!(
            map_error(core::Error::NoChange),
            TextBufferError::TransactionConflict
        );
    }

    #[test]
    fn transaction_and_snapshot_conversions_preserve_nested_values() {
        let selection = core::Selection {
            id: "primary".into(),
            anchor: core::Position {
                line: 2,
                utf16_offset: 3,
            },
            head: core::Position {
                line: 0,
                utf16_offset: 0,
            },
            primary: true,
        };
        let transaction = core::Transaction {
            id: "tx-λ".into(),
            base_revision: 42,
            origin: "external".into(),
            edits: vec![core::Edit {
                range: core::Range {
                    start: selection.head.clone(),
                    end: selection.anchor.clone(),
                },
                text: "hello 🎉".into(),
            }],
            selections: vec![selection.clone()],
        };
        #[cfg(feature = "components")]
        assert_eq!(
            to_core_transaction(from_core_transaction(transaction.clone())),
            transaction
        );
        #[cfg(not(feature = "components"))]
        let _ = transaction;

        let snapshot = from_core_snapshot(core::Snapshot {
            revision: 43,
            text: "hello 🎉".into(),
            selections: vec![selection.clone()],
            can_undo: true,
            can_redo: false,
        });
        assert_eq!(snapshot.revision, 43);
        assert_eq!(snapshot.text, "hello 🎉");
        assert!(snapshot.can_undo);
        assert!(!snapshot.can_redo);
        assert_eq!(to_core_selection(snapshot.selections[0].clone()), selection);
        let result = from_core_result(core::TransactionResult {
            revision: 43,
            duplicate: true,
            selections: vec![selection.clone()],
        });
        assert_eq!(result.revision, 43);
        assert!(result.duplicate);
        assert_eq!(to_core_selection(result.selections[0].clone()), selection);
    }

    #[test]
    fn selection_round_trip_preserves_identity_direction_and_primary_flag() {
        let selection = TextSelection {
            id: "secondary-λ".into(),
            anchor: TextPosition {
                line: u64::MAX,
                utf16_offset: 4,
            },
            head: TextPosition {
                line: 2,
                utf16_offset: 1,
            },
            primary: false,
        };
        assert_eq!(
            from_core_selection(to_core_selection(selection.clone())),
            selection
        );
    }

    #[test]
    fn range_conversion_preserves_endpoints_without_normalizing() {
        let range = TextRange {
            start: TextPosition {
                line: 9,
                utf16_offset: 4,
            },
            end: TextPosition {
                line: 2,
                utf16_offset: 1,
            },
        };
        let converted = to_core_range(range.clone());
        assert_eq!(converted.start.line, range.start.line);
        assert_eq!(converted.start.utf16_offset, range.start.utf16_offset);
        assert_eq!(converted.end.line, range.end.line);
        assert_eq!(converted.end.utf16_offset, range.end.utf16_offset);
        #[cfg(feature = "components")]
        assert_eq!(from_core_range(converted), range);
    }
}
