use ropey::{LineType, Rope};
use rustler::NifMap;
use std::collections::{HashMap, VecDeque};
#[cfg(feature = "components")]
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

const MAX_HISTORY: usize = 1_000;
const MAX_TRANSACTION_IDS: usize = 4_096;
#[cfg(feature = "components")]
static NEXT_NATIVE_TRANSACTION_ID: AtomicU64 = AtomicU64::new(1);

#[cfg(feature = "components")]
pub(crate) fn next_native_transaction_id(surface_id: &str) -> String {
    let sequence = NEXT_NATIVE_TRANSACTION_ID.fetch_add(1, Ordering::Relaxed);
    format!("native-{surface_id}-{sequence}")
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TextPosition {
    pub(crate) line: u64,
    pub(crate) utf16_offset: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TextRange {
    pub(crate) start: TextPosition,
    pub(crate) end: TextPosition,
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TextEdit {
    pub(crate) range: TextRange,
    pub(crate) text: String,
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TextSelection {
    pub(crate) id: String,
    pub(crate) anchor: TextPosition,
    pub(crate) head: TextPosition,
    pub(crate) primary: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TextTransaction {
    pub(crate) id: String,
    pub(crate) base_revision: u64,
    pub(crate) origin: String,
    pub(crate) edits: Vec<TextEdit>,
    pub(crate) selections: Vec<TextSelection>,
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TextSnapshot {
    pub(crate) revision: u64,
    pub(crate) text: String,
    pub(crate) selections: Vec<TextSelection>,
    pub(crate) can_undo: bool,
    pub(crate) can_redo: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, NifMap)]
pub(crate) struct TransactionResult {
    pub(crate) revision: u64,
    pub(crate) duplicate: bool,
    pub(crate) selections: Vec<TextSelection>,
}

#[derive(Clone)]
struct HistoryEntry {
    before_text: Rope,
    before_selections: Vec<TextSelection>,
    after_text: Rope,
    after_selections: Vec<TextSelection>,
}

#[derive(Clone)]
struct AppliedTransaction {
    transaction: TextTransaction,
    revision: u64,
}

struct TextBufferState {
    text: Rope,
    revision: u64,
    selections: Vec<TextSelection>,
    undo: VecDeque<HistoryEntry>,
    redo: Vec<HistoryEntry>,
    transactions: HashMap<String, AppliedTransaction>,
    transaction_order: VecDeque<String>,
}

pub(crate) struct TextBufferResource {
    state: Mutex<TextBufferState>,
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
        let text = Rope::from(text);
        validate_selections(&text, &selections)?;

        Ok(Self {
            state: Mutex::new(TextBufferState {
                text,
                revision,
                selections,
                undo: VecDeque::new(),
                redo: Vec::new(),
                transactions: HashMap::new(),
                transaction_order: VecDeque::new(),
            }),
        })
    }

    #[cfg(feature = "components")]
    pub(crate) fn revision(&self) -> Result<u64, TextBufferError> {
        self.state
            .lock()
            .map(|state| state.revision)
            .map_err(|_| TextBufferError::LockFailed)
    }

    #[cfg(feature = "components")]
    pub(crate) fn replace_from_surface(
        &self,
        base_revision: u64,
        transaction_id: String,
        text: String,
        selection: TextSelection,
    ) -> Result<(TextTransaction, u64), TextBufferError> {
        let mut state = self.state.lock().map_err(|_| TextBufferError::LockFailed)?;
        require_revision(&state, base_revision)?;
        let selections = vec![selection];
        let next_text = Rope::from(text.clone());
        validate_selections(&next_text, &selections)?;
        let edit = minimal_replacement_edit(&state.text.to_string(), &text);
        let transaction = TextTransaction {
            id: transaction_id,
            base_revision,
            origin: "local".into(),
            edits: edit.into_iter().collect(),
            selections: selections.clone(),
        };
        if transaction.edits.is_empty() && state.selections == selections {
            return Err(TextBufferError::NoChange);
        }
        let entry = HistoryEntry {
            before_text: state.text.clone(),
            before_selections: state.selections.clone(),
            after_text: next_text.clone(),
            after_selections: selections.clone(),
        };
        state.text = next_text;
        state.selections = selections;
        state.revision = state.revision.saturating_add(1);
        state.undo.push_back(entry);
        if state.undo.len() > MAX_HISTORY {
            state.undo.pop_front();
        }
        state.redo.clear();
        let revision = state.revision;
        Ok((transaction, revision))
    }

    #[cfg(feature = "components")]
    pub(crate) fn update_selection_from_surface(
        &self,
        base_revision: u64,
        selection: TextSelection,
    ) -> Result<u64, TextBufferError> {
        let mut state = self.state.lock().map_err(|_| TextBufferError::LockFailed)?;
        require_revision(&state, base_revision)?;
        let selections = vec![selection];
        validate_selections(&state.text, &selections)?;
        if state.selections == selections {
            return Err(TextBufferError::NoChange);
        }
        state.selections = selections;
        state.revision = state.revision.saturating_add(1);
        Ok(state.revision)
    }

    pub(crate) fn snapshot(&self) -> Result<TextSnapshot, TextBufferError> {
        let state = self.state.lock().map_err(|_| TextBufferError::LockFailed)?;
        Ok(snapshot(&state))
    }

    pub(crate) fn transact(
        &self,
        transaction: TextTransaction,
    ) -> Result<TransactionResult, TextBufferError> {
        let mut state = self.state.lock().map_err(|_| TextBufferError::LockFailed)?;

        if transaction.id.is_empty() {
            return Err(TextBufferError::TransactionConflict);
        }

        if let Some(applied) = state.transactions.get(&transaction.id) {
            return if applied.transaction == transaction {
                Ok(TransactionResult {
                    revision: applied.revision,
                    duplicate: true,
                    selections: applied.transaction.selections.clone(),
                })
            } else {
                Err(TextBufferError::TransactionConflict)
            };
        }

        if transaction.base_revision != state.revision {
            return Err(TextBufferError::StaleRevision(state.revision));
        }

        let mut edits = decoded_edits(&state.text, &transaction.edits)?;
        let mut next_text = state.text.clone();
        edits.sort_by_key(|edit| edit.start);
        validate_non_overlapping(&edits)?;

        for edit in edits.iter().rev() {
            next_text.remove(edit.start..edit.end);
            next_text.insert(edit.start, &edit.text);
        }
        validate_selections(&next_text, &transaction.selections)?;

        let entry = HistoryEntry {
            before_text: state.text.clone(),
            before_selections: state.selections.clone(),
            after_text: next_text.clone(),
            after_selections: transaction.selections.clone(),
        };
        let changes_text = !transaction.edits.is_empty();
        state.text = next_text;
        state.selections = transaction.selections.clone();
        state.revision = state.revision.saturating_add(1);
        if changes_text {
            state.undo.push_back(entry);
            if state.undo.len() > MAX_HISTORY {
                state.undo.pop_front();
            }
            state.redo.clear();
        }

        let revision = state.revision;
        remember_transaction(&mut state, transaction.clone(), revision);

        Ok(TransactionResult {
            revision,
            duplicate: false,
            selections: transaction.selections,
        })
    }

    pub(crate) fn undo(&self, base_revision: u64) -> Result<TextSnapshot, TextBufferError> {
        let mut state = self.state.lock().map_err(|_| TextBufferError::LockFailed)?;
        require_revision(&state, base_revision)?;
        let entry = state
            .undo
            .pop_back()
            .ok_or(TextBufferError::NothingToUndo)?;
        state.text = entry.before_text.clone();
        state.selections = entry.before_selections.clone();
        state.revision = state.revision.saturating_add(1);
        state.redo.push(entry);
        Ok(snapshot(&state))
    }

    pub(crate) fn redo(&self, base_revision: u64) -> Result<TextSnapshot, TextBufferError> {
        let mut state = self.state.lock().map_err(|_| TextBufferError::LockFailed)?;
        require_revision(&state, base_revision)?;
        let entry = state.redo.pop().ok_or(TextBufferError::NothingToRedo)?;
        state.text = entry.after_text.clone();
        state.selections = entry.after_selections.clone();
        state.revision = state.revision.saturating_add(1);
        state.undo.push_back(entry);
        Ok(snapshot(&state))
    }
}

#[derive(Debug)]
struct DecodedEdit {
    start: usize,
    end: usize,
    text: String,
}

fn decoded_edits(text: &Rope, edits: &[TextEdit]) -> Result<Vec<DecodedEdit>, TextBufferError> {
    edits
        .iter()
        .map(|edit| {
            let start = position_to_byte(text, &edit.range.start)?;
            let end = position_to_byte(text, &edit.range.end)?;
            if end < start {
                return Err(TextBufferError::InvalidRange);
            }
            Ok(DecodedEdit {
                start,
                end,
                text: edit.text.clone(),
            })
        })
        .collect()
}

fn validate_non_overlapping(edits: &[DecodedEdit]) -> Result<(), TextBufferError> {
    for pair in edits.windows(2) {
        let previous = &pair[0];
        let current = &pair[1];
        let duplicate_insert = previous.start == previous.end
            && current.start == current.end
            && previous.start == current.start;
        if previous.end > current.start || duplicate_insert {
            return Err(TextBufferError::OverlappingEdits);
        }
    }
    Ok(())
}

fn validate_selections(text: &Rope, selections: &[TextSelection]) -> Result<(), TextBufferError> {
    if selections.len() != 1
        || !selections[0].primary
        || selections[0].id.is_empty()
        || position_to_byte(text, &selections[0].anchor).is_err()
        || position_to_byte(text, &selections[0].head).is_err()
    {
        return Err(TextBufferError::InvalidSelection);
    }
    Ok(())
}

fn position_to_byte(text: &Rope, position: &TextPosition) -> Result<usize, TextBufferError> {
    let line = usize::try_from(position.line).map_err(|_| TextBufferError::InvalidPosition)?;
    let target =
        usize::try_from(position.utf16_offset).map_err(|_| TextBufferError::InvalidPosition)?;
    if line >= text.len_lines(LineType::LF) {
        return Err(TextBufferError::InvalidPosition);
    }

    let line_start = text.line_to_byte_idx(line, LineType::LF);
    let line_end = if line + 1 < text.len_lines(LineType::LF) {
        text.line_to_byte_idx(line + 1, LineType::LF)
    } else {
        text.len()
    };
    let mut content = text.slice(line_start..line_end).to_string();
    if content.ends_with('\n') {
        content.pop();
        if content.ends_with('\r') {
            content.pop();
        }
    }

    let mut utf16_offset = 0;
    for (byte_offset, character) in content.char_indices() {
        if utf16_offset == target {
            return Ok(line_start + byte_offset);
        }
        let next = utf16_offset + character.len_utf16();
        if target < next {
            return Err(TextBufferError::InvalidPosition);
        }
        utf16_offset = next;
    }

    if utf16_offset == target {
        Ok(line_start + content.len())
    } else {
        Err(TextBufferError::InvalidPosition)
    }
}

#[cfg(any(test, feature = "components"))]
fn minimal_replacement_edit(before: &str, after: &str) -> Option<TextEdit> {
    if before == after {
        return None;
    }

    let prefix = before
        .char_indices()
        .zip(after.char_indices())
        .take_while(|((_, left), (_, right))| left == right)
        .map(|((offset, character), _)| offset + character.len_utf8())
        .last()
        .unwrap_or(0);
    let before_tail = &before[prefix..];
    let after_tail = &after[prefix..];
    let suffix = before_tail
        .chars()
        .rev()
        .zip(after_tail.chars().rev())
        .take_while(|(left, right)| left == right)
        .map(|(character, _)| character.len_utf8())
        .sum::<usize>();
    let before_end = before.len() - suffix;
    let after_end = after.len() - suffix;
    let rope = Rope::from(before);

    Some(TextEdit {
        range: TextRange {
            start: byte_to_position(&rope, prefix),
            end: byte_to_position(&rope, before_end),
        },
        text: after[prefix..after_end].to_string(),
    })
}

#[cfg(any(test, feature = "components"))]
fn byte_to_position(text: &Rope, byte_offset: usize) -> TextPosition {
    let byte_offset = byte_offset.min(text.len());
    let line = text.byte_to_line_idx(byte_offset, LineType::LF);
    let line_start = text.line_to_byte_idx(line, LineType::LF);
    let utf16_offset = text
        .slice(line_start..byte_offset)
        .chars()
        .map(char::len_utf16)
        .sum::<usize>();
    TextPosition {
        line: line as u64,
        utf16_offset: utf16_offset as u64,
    }
}

#[cfg(any(test, feature = "components"))]
pub(crate) fn position_to_byte_offset(
    text: &str,
    position: &TextPosition,
) -> Result<usize, TextBufferError> {
    position_to_byte(&Rope::from(text), position)
}

#[cfg(any(test, feature = "components"))]
pub(crate) fn range_to_byte_range(
    text: &str,
    range: &TextRange,
) -> Result<std::ops::Range<usize>, TextBufferError> {
    let rope = Rope::from(text);
    let start = position_to_byte(&rope, &range.start)?;
    let end = position_to_byte(&rope, &range.end)?;
    if end < start {
        return Err(TextBufferError::InvalidRange);
    }
    Ok(start..end)
}

#[cfg(any(test, feature = "components"))]
pub(crate) fn selection_to_byte_range(
    text: &str,
    selection: &TextSelection,
) -> Result<std::ops::Range<usize>, TextBufferError> {
    let rope = Rope::from(text);
    let anchor = position_to_byte(&rope, &selection.anchor)?;
    let head = position_to_byte(&rope, &selection.head)?;
    Ok(anchor.min(head)..anchor.max(head))
}

#[cfg(any(test, feature = "components"))]
pub(crate) fn byte_range_to_selection(
    text: &str,
    range: std::ops::Range<usize>,
) -> Result<TextSelection, TextBufferError> {
    let rope = Rope::from(text);
    if range.start > range.end || range.end > rope.len() {
        return Err(TextBufferError::InvalidSelection);
    }
    Ok(TextSelection {
        id: "primary".into(),
        anchor: byte_to_position(&rope, range.start),
        head: byte_to_position(&rope, range.end),
        primary: true,
    })
}

fn require_revision(state: &TextBufferState, revision: u64) -> Result<(), TextBufferError> {
    if revision == state.revision {
        Ok(())
    } else {
        Err(TextBufferError::StaleRevision(state.revision))
    }
}

fn remember_transaction(state: &mut TextBufferState, transaction: TextTransaction, revision: u64) {
    if state.transactions.len() >= MAX_TRANSACTION_IDS {
        if let Some(oldest) = state.transaction_order.pop_front() {
            state.transactions.remove(&oldest);
        }
    }
    state.transaction_order.push_back(transaction.id.clone());
    state.transactions.insert(
        transaction.id.clone(),
        AppliedTransaction {
            transaction,
            revision,
        },
    );
}

fn snapshot(state: &TextBufferState) -> TextSnapshot {
    TextSnapshot {
        revision: state.revision,
        text: state.text.to_string(),
        selections: state.selections.clone(),
        can_undo: !state.undo.is_empty(),
        can_redo: !state.redo.is_empty(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn position(line: u64, utf16_offset: u64) -> TextPosition {
        TextPosition { line, utf16_offset }
    }

    fn selection(position: TextPosition) -> Vec<TextSelection> {
        vec![TextSelection {
            id: "primary".into(),
            anchor: position.clone(),
            head: position,
            primary: true,
        }]
    }

    fn transaction(id: &str, base_revision: u64, range: TextRange, text: &str) -> TextTransaction {
        TextTransaction {
            id: id.into(),
            base_revision,
            origin: "external".into(),
            edits: vec![TextEdit {
                range,
                text: text.into(),
            }],
            selections: selection(position(0, 2)),
        }
    }

    #[test]
    fn positions_convert_utf16_offsets_to_bytes() {
        assert_eq!(position_to_byte_offset("a🎉b", &position(0, 3)), Ok(5));
    }

    #[test]
    fn text_ranges_convert_utf16_positions_to_bytes() {
        let range = TextRange {
            start: position(0, 1),
            end: position(0, 3),
        };
        assert_eq!(range_to_byte_range("a🎉b", &range), Ok(1..5));
    }

    #[test]
    fn minimal_native_edits_preserve_unicode_boundaries() {
        let edit = minimal_replacement_edit("a🎉b", "a中🎉b").unwrap();
        assert_eq!(edit.range.start, position(0, 1));
        assert_eq!(edit.range.end, position(0, 1));
        assert_eq!(edit.text, "中");

        let edit = minimal_replacement_edit("a🎉b", "ab").unwrap();
        assert_eq!(edit.range.start, position(0, 1));
        assert_eq!(edit.range.end, position(0, 3));
        assert_eq!(edit.text, "");
    }

    #[test]
    fn native_selection_ranges_use_utf16_coordinates() {
        let selection = byte_range_to_selection("a🎉中", 1..5).unwrap();
        assert_eq!(selection.anchor, position(0, 1));
        assert_eq!(selection.head, position(0, 3));
        assert_eq!(selection_to_byte_range("a🎉中", &selection).unwrap(), 1..5);
    }

    #[test]
    fn applies_utf16_edits_and_rejects_surrogate_splits() {
        let buffer =
            TextBufferResource::new("a🎉b\r\n中文".into(), 7, selection(position(0, 0))).unwrap();
        let edit = transaction(
            "replace-emoji",
            7,
            TextRange {
                start: position(0, 1),
                end: position(0, 3),
            },
            "é",
        );
        assert_eq!(buffer.transact(edit).unwrap().revision, 8);
        assert_eq!(buffer.snapshot().unwrap().text, "aéb\r\n中文");

        let invalid = transaction(
            "split-surrogate",
            0,
            TextRange {
                start: position(0, 1),
                end: position(0, 1),
            },
            "x",
        );
        // The emoji is gone, so use a fresh buffer to verify the split itself.
        let emoji = TextBufferResource::new("🎉".into(), 0, selection(position(0, 0))).unwrap();
        assert_eq!(
            emoji.transact(invalid),
            Err(TextBufferError::InvalidPosition)
        );
    }

    #[test]
    fn addresses_cjk_and_combining_code_points_in_utf16_units() {
        let buffer =
            TextBufferResource::new("中e\u{301}文".into(), 0, selection(position(0, 0))).unwrap();
        let edit = transaction(
            "replace-combining-mark",
            0,
            TextRange {
                start: position(0, 2),
                end: position(0, 3),
            },
            "",
        );
        buffer.transact(edit).unwrap();
        assert_eq!(buffer.snapshot().unwrap().text, "中e文");
    }

    #[test]
    fn applies_multiple_base_revision_edits_atomically() {
        let buffer =
            TextBufferResource::new("one two three".into(), 0, selection(position(0, 0))).unwrap();
        let transaction = TextTransaction {
            id: "multiple".into(),
            base_revision: 0,
            origin: "external".into(),
            edits: vec![
                TextEdit {
                    range: TextRange {
                        start: position(0, 0),
                        end: position(0, 3),
                    },
                    text: "1".into(),
                },
                TextEdit {
                    range: TextRange {
                        start: position(0, 8),
                        end: position(0, 13),
                    },
                    text: "3".into(),
                },
            ],
            selections: selection(position(0, 1)),
        };
        buffer.transact(transaction).unwrap();
        assert_eq!(buffer.snapshot().unwrap().text, "1 two 3");
    }

    #[test]
    fn transactions_are_stale_safe_idempotent_and_conflict_checked() {
        let buffer = TextBufferResource::new("ab".into(), 0, selection(position(0, 0))).unwrap();
        let edit = transaction(
            "insert",
            0,
            TextRange {
                start: position(0, 1),
                end: position(0, 1),
            },
            "x",
        );
        let first = buffer.transact(edit.clone()).unwrap();
        assert!(!first.duplicate);
        assert!(buffer.transact(edit.clone()).unwrap().duplicate);

        let mut conflict = edit;
        conflict.edits[0].text = "y".into();
        assert_eq!(
            buffer.transact(conflict),
            Err(TextBufferError::TransactionConflict)
        );
        assert_eq!(
            buffer.transact(transaction(
                "stale",
                0,
                TextRange {
                    start: position(0, 0),
                    end: position(0, 0),
                },
                "z"
            )),
            Err(TextBufferError::StaleRevision(1))
        );
    }

    #[test]
    fn selection_only_transactions_do_not_create_undo_history() {
        let buffer = TextBufferResource::new("ab".into(), 0, selection(position(0, 0))).unwrap();
        let moved = TextTransaction {
            id: "move-selection".into(),
            base_revision: 0,
            origin: "external".into(),
            edits: vec![],
            selections: selection(position(0, 1)),
        };

        let result = buffer.transact(moved).unwrap();
        assert_eq!(result.revision, 1);
        let snapshot = buffer.snapshot().unwrap();
        assert_eq!(snapshot.text, "ab");
        assert!(!snapshot.can_undo);
        assert!(!snapshot.can_redo);
        assert_eq!(buffer.undo(1), Err(TextBufferError::NothingToUndo));
    }

    #[cfg(feature = "components")]
    #[test]
    fn native_selection_updates_do_not_create_undo_history() {
        let buffer = TextBufferResource::new("a🎉b".into(), 0, selection(position(0, 0))).unwrap();
        let moved = byte_range_to_selection("a🎉b", 1..5).unwrap();

        assert_eq!(buffer.update_selection_from_surface(0, moved), Ok(1));
        let snapshot = buffer.snapshot().unwrap();
        assert_eq!(snapshot.selections[0].anchor, position(0, 1));
        assert_eq!(snapshot.selections[0].head, position(0, 3));
        assert!(!snapshot.can_undo);
        assert_eq!(buffer.undo(1), Err(TextBufferError::NothingToUndo));
    }

    #[test]
    fn undo_and_redo_create_monotonic_revisions() {
        let buffer = TextBufferResource::new("ab".into(), 0, selection(position(0, 0))).unwrap();
        buffer
            .transact(transaction(
                "insert",
                0,
                TextRange {
                    start: position(0, 1),
                    end: position(0, 1),
                },
                "x",
            ))
            .unwrap();
        let undone = buffer.undo(1).unwrap();
        assert_eq!((undone.revision, undone.text.as_str()), (2, "ab"));
        let redone = buffer.redo(2).unwrap();
        assert_eq!((redone.revision, redone.text.as_str()), (3, "axb"));
    }

    #[test]
    fn crlf_line_endings_are_not_addressable_content() {
        let text = Rope::from("a\r\nb");
        assert_eq!(position_to_byte(&text, &position(0, 1)), Ok(1));
        assert_eq!(
            position_to_byte(&text, &position(0, 2)),
            Err(TextBufferError::InvalidPosition)
        );
        assert_eq!(position_to_byte(&text, &position(1, 0)), Ok(3));
    }
}
