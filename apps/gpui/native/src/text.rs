use ropey::{LineType, Rope};
use std::collections::{HashMap, VecDeque};

const MAX_HISTORY: usize = 1_000;
const MAX_TRANSACTION_IDS: usize = 4_096;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Position {
    pub line: u64,
    pub utf16_offset: u64,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Range {
    pub start: Position,
    pub end: Position,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Selection {
    pub id: String,
    pub anchor: Position,
    pub head: Position,
    pub primary: bool,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Edit {
    pub range: Range,
    pub text: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Transaction {
    pub id: String,
    pub base_revision: u64,
    pub origin: String,
    pub edits: Vec<Edit>,
    pub selections: Vec<Selection>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    pub revision: u64,
    pub text: String,
    pub selections: Vec<Selection>,
    pub can_undo: bool,
    pub can_redo: bool,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TransactionResult {
    pub revision: u64,
    pub duplicate: bool,
    pub selections: Vec<Selection>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Error {
    InvalidPosition,
    InvalidRange,
    InvalidSelection,
    OverlappingEdits,
    StaleRevision(u64),
    TransactionConflict,
    NothingToUndo,
    NothingToRedo,
    NoChange,
}

#[derive(Clone)]
struct HistoryEntry {
    before_text: Rope,
    before_selections: Vec<Selection>,
    after_text: Rope,
    after_selections: Vec<Selection>,
}
#[derive(Clone)]
struct AppliedTransaction {
    transaction: Transaction,
    revision: u64,
}

pub struct Buffer {
    text: Rope,
    revision: u64,
    selections: Vec<Selection>,
    undo: VecDeque<HistoryEntry>,
    redo: Vec<HistoryEntry>,
    transactions: HashMap<String, AppliedTransaction>,
    transaction_order: VecDeque<String>,
}

impl Buffer {
    pub fn new(text: String, revision: u64, selections: Vec<Selection>) -> Result<Self, Error> {
        let text = Rope::from(text);
        validate_selections(&text, &selections)?;
        Ok(Self {
            text,
            revision,
            selections,
            undo: VecDeque::new(),
            redo: Vec::new(),
            transactions: HashMap::new(),
            transaction_order: VecDeque::new(),
        })
    }

    pub fn revision(&self) -> u64 {
        self.revision
    }
    pub fn snapshot(&self) -> Snapshot {
        snapshot(self)
    }

    pub fn transact(&mut self, transaction: Transaction) -> Result<TransactionResult, Error> {
        if transaction.id.is_empty() {
            return Err(Error::TransactionConflict);
        }
        if let Some(applied) = self.transactions.get(&transaction.id) {
            return if applied.transaction == transaction {
                Ok(TransactionResult {
                    revision: applied.revision,
                    duplicate: true,
                    selections: applied.transaction.selections.clone(),
                })
            } else {
                Err(Error::TransactionConflict)
            };
        }
        self.require_revision(transaction.base_revision)?;
        let mut edits = decoded_edits(&self.text, &transaction.edits)?;
        edits.sort_by_key(|edit| edit.start);
        validate_non_overlapping(&edits)?;
        let mut next_text = self.text.clone();
        for edit in edits.iter().rev() {
            next_text.remove(edit.start..edit.end);
            next_text.insert(edit.start, &edit.text);
        }
        validate_selections(&next_text, &transaction.selections)?;
        let entry = HistoryEntry {
            before_text: self.text.clone(),
            before_selections: self.selections.clone(),
            after_text: next_text.clone(),
            after_selections: transaction.selections.clone(),
        };
        let changes_text = !transaction.edits.is_empty();
        self.text = next_text;
        self.selections = transaction.selections.clone();
        self.revision = self.revision.saturating_add(1);
        if changes_text {
            self.push_undo(entry);
            self.redo.clear();
        }
        let revision = self.revision;
        self.remember_transaction(transaction.clone(), revision);
        Ok(TransactionResult {
            revision,
            duplicate: false,
            selections: transaction.selections,
        })
    }

    pub fn replace_from_surface(
        &mut self,
        base_revision: u64,
        transaction_id: String,
        text: String,
        selection: Selection,
    ) -> Result<(Transaction, u64), Error> {
        self.require_revision(base_revision)?;
        let selections = vec![selection];
        let next_text = Rope::from(text.clone());
        validate_selections(&next_text, &selections)?;
        let transaction = Transaction {
            id: transaction_id,
            base_revision,
            origin: "local".into(),
            edits: minimal_replacement_edit(&self.text.to_string(), &text)
                .into_iter()
                .collect(),
            selections: selections.clone(),
        };
        if transaction.edits.is_empty() && self.selections == selections {
            return Err(Error::NoChange);
        }
        let entry = HistoryEntry {
            before_text: self.text.clone(),
            before_selections: self.selections.clone(),
            after_text: next_text.clone(),
            after_selections: selections.clone(),
        };
        self.text = next_text;
        self.selections = selections;
        self.revision = self.revision.saturating_add(1);
        self.push_undo(entry);
        self.redo.clear();
        Ok((transaction, self.revision))
    }

    pub fn update_selection_from_surface(
        &mut self,
        base_revision: u64,
        selection: Selection,
    ) -> Result<u64, Error> {
        self.require_revision(base_revision)?;
        let selections = vec![selection];
        validate_selections(&self.text, &selections)?;
        if self.selections == selections {
            return Err(Error::NoChange);
        }
        self.selections = selections;
        self.revision = self.revision.saturating_add(1);
        Ok(self.revision)
    }

    pub fn undo(&mut self, base_revision: u64) -> Result<Snapshot, Error> {
        self.require_revision(base_revision)?;
        let entry = self.undo.pop_back().ok_or(Error::NothingToUndo)?;
        self.text = entry.before_text.clone();
        self.selections = entry.before_selections.clone();
        self.revision = self.revision.saturating_add(1);
        self.redo.push(entry);
        Ok(snapshot(self))
    }

    pub fn redo(&mut self, base_revision: u64) -> Result<Snapshot, Error> {
        self.require_revision(base_revision)?;
        let entry = self.redo.pop().ok_or(Error::NothingToRedo)?;
        self.text = entry.after_text.clone();
        self.selections = entry.after_selections.clone();
        self.revision = self.revision.saturating_add(1);
        self.undo.push_back(entry);
        Ok(snapshot(self))
    }

    fn require_revision(&self, revision: u64) -> Result<(), Error> {
        if revision == self.revision {
            Ok(())
        } else {
            Err(Error::StaleRevision(self.revision))
        }
    }
    fn push_undo(&mut self, entry: HistoryEntry) {
        self.undo.push_back(entry);
        if self.undo.len() > MAX_HISTORY {
            self.undo.pop_front();
        }
    }
    fn remember_transaction(&mut self, transaction: Transaction, revision: u64) {
        if self.transactions.len() >= MAX_TRANSACTION_IDS {
            if let Some(oldest) = self.transaction_order.pop_front() {
                self.transactions.remove(&oldest);
            }
        }
        self.transaction_order.push_back(transaction.id.clone());
        self.transactions.insert(
            transaction.id.clone(),
            AppliedTransaction {
                transaction,
                revision,
            },
        );
    }
}

struct DecodedEdit {
    start: usize,
    end: usize,
    text: String,
}
fn decoded_edits(text: &Rope, edits: &[Edit]) -> Result<Vec<DecodedEdit>, Error> {
    edits
        .iter()
        .map(|edit| {
            let start = position_to_byte(text, &edit.range.start)?;
            let end = position_to_byte(text, &edit.range.end)?;
            if end < start {
                return Err(Error::InvalidRange);
            }
            Ok(DecodedEdit {
                start,
                end,
                text: edit.text.clone(),
            })
        })
        .collect()
}
fn validate_non_overlapping(edits: &[DecodedEdit]) -> Result<(), Error> {
    for pair in edits.windows(2) {
        let (previous, current) = (&pair[0], &pair[1]);
        if previous.end > current.start
            || (previous.start == previous.end
                && current.start == current.end
                && previous.start == current.start)
        {
            return Err(Error::OverlappingEdits);
        }
    }
    Ok(())
}
fn validate_selections(text: &Rope, selections: &[Selection]) -> Result<(), Error> {
    if selections.len() != 1
        || !selections[0].primary
        || selections[0].id.is_empty()
        || position_to_byte(text, &selections[0].anchor).is_err()
        || position_to_byte(text, &selections[0].head).is_err()
    {
        Err(Error::InvalidSelection)
    } else {
        Ok(())
    }
}

fn position_to_byte(text: &Rope, position: &Position) -> Result<usize, Error> {
    let line = usize::try_from(position.line).map_err(|_| Error::InvalidPosition)?;
    let target = usize::try_from(position.utf16_offset).map_err(|_| Error::InvalidPosition)?;
    if line >= text.len_lines(LineType::LF) {
        return Err(Error::InvalidPosition);
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
            return Err(Error::InvalidPosition);
        }
        utf16_offset = next;
    }
    if utf16_offset == target {
        Ok(line_start + content.len())
    } else {
        Err(Error::InvalidPosition)
    }
}
fn byte_to_position(text: &Rope, byte_offset: usize) -> Position {
    let byte_offset = byte_offset.min(text.len());
    let line = text.byte_to_line_idx(byte_offset, LineType::LF);
    let line_start = text.line_to_byte_idx(line, LineType::LF);
    let utf16_offset = text
        .slice(line_start..byte_offset)
        .chars()
        .map(char::len_utf16)
        .sum::<usize>();
    Position {
        line: line as u64,
        utf16_offset: utf16_offset as u64,
    }
}
pub fn position_to_byte_offset(text: &str, position: &Position) -> Result<usize, Error> {
    position_to_byte(&Rope::from(text), position)
}
pub fn range_to_byte_range(text: &str, range: &Range) -> Result<std::ops::Range<usize>, Error> {
    let rope = Rope::from(text);
    let start = position_to_byte(&rope, &range.start)?;
    let end = position_to_byte(&rope, &range.end)?;
    if end < start {
        Err(Error::InvalidRange)
    } else {
        Ok(start..end)
    }
}
pub fn selection_to_byte_range(
    text: &str,
    selection: &Selection,
) -> Result<std::ops::Range<usize>, Error> {
    let rope = Rope::from(text);
    let anchor = position_to_byte(&rope, &selection.anchor)?;
    let head = position_to_byte(&rope, &selection.head)?;
    Ok(anchor.min(head)..anchor.max(head))
}
pub fn byte_range_to_selection(
    text: &str,
    range: std::ops::Range<usize>,
) -> Result<Selection, Error> {
    let rope = Rope::from(text);
    if range.start > range.end || range.end > rope.len() {
        return Err(Error::InvalidSelection);
    }
    Ok(Selection {
        id: "primary".into(),
        anchor: byte_to_position(&rope, range.start),
        head: byte_to_position(&rope, range.end),
        primary: true,
    })
}
fn minimal_replacement_edit(before: &str, after: &str) -> Option<Edit> {
    if before == after {
        return None;
    }
    let prefix = before
        .char_indices()
        .zip(after.char_indices())
        .take_while(|((_, l), (_, r))| l == r)
        .map(|((offset, character), _)| offset + character.len_utf8())
        .last()
        .unwrap_or(0);
    let before_tail = &before[prefix..];
    let after_tail = &after[prefix..];
    let suffix = before_tail
        .chars()
        .rev()
        .zip(after_tail.chars().rev())
        .take_while(|(l, r)| l == r)
        .map(|(character, _)| character.len_utf8())
        .sum::<usize>();
    let rope = Rope::from(before);
    Some(Edit {
        range: Range {
            start: byte_to_position(&rope, prefix),
            end: byte_to_position(&rope, before.len() - suffix),
        },
        text: after[prefix..after.len() - suffix].to_string(),
    })
}
fn snapshot(state: &Buffer) -> Snapshot {
    Snapshot {
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
    fn p(line: u64, utf16_offset: u64) -> Position {
        Position { line, utf16_offset }
    }
    fn selections(position: Position) -> Vec<Selection> {
        vec![Selection {
            id: "primary".into(),
            anchor: position.clone(),
            head: position,
            primary: true,
        }]
    }
    #[test]
    fn converts_utf16_positions() {
        assert_eq!(position_to_byte_offset("a🎉b", &p(0, 3)), Ok(5));
    }
    #[test]
    fn applies_and_reverses_transactions() {
        let mut buffer = Buffer::new("ab".into(), 0, selections(p(0, 0))).unwrap();
        let transaction = Transaction {
            id: "insert".into(),
            base_revision: 0,
            origin: "external".into(),
            edits: vec![Edit {
                range: Range {
                    start: p(0, 1),
                    end: p(0, 1),
                },
                text: "x".into(),
            }],
            selections: selections(p(0, 2)),
        };
        assert_eq!(buffer.transact(transaction).unwrap().revision, 1);
        assert_eq!(buffer.undo(1).unwrap().text, "ab");
        assert_eq!(buffer.redo(2).unwrap().text, "axb");
    }
}
