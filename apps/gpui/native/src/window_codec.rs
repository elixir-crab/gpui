use std::collections::HashSet;

pub const MAX_WINDOW_COMMANDS: usize = 64;
pub const MAX_COMMAND_ID_BYTES: usize = 128;
pub const MAX_SHORTCUT_BYTES: usize = 64;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CommandValidationError {
    TooManyCommands,
    DuplicateId,
    DuplicateShortcut,
    InvalidCommand,
}

pub fn validate_commands(commands: &[(String, String)]) -> Result<(), CommandValidationError> {
    if commands.len() > MAX_WINDOW_COMMANDS {
        return Err(CommandValidationError::TooManyCommands);
    }

    let mut ids = HashSet::new();
    let mut shortcuts = HashSet::new();

    for (id, shortcut) in commands {
        if !ids.insert(id) {
            return Err(CommandValidationError::DuplicateId);
        }
        if !shortcuts.insert(shortcut) {
            return Err(CommandValidationError::DuplicateShortcut);
        }
        if !valid_command(id, shortcut) {
            return Err(CommandValidationError::InvalidCommand);
        }
    }

    Ok(())
}

pub fn valid_command(id: &str, shortcut: &str) -> bool {
    !id.is_empty() && id.len() <= MAX_COMMAND_ID_BYTES && valid_shortcut(shortcut)
}

pub fn valid_shortcut(shortcut: &str) -> bool {
    if shortcut.is_empty() || shortcut.len() > MAX_SHORTCUT_BYTES {
        return false;
    }

    let parts = shortcut.split('-').collect::<Vec<_>>();
    let Some((key, modifiers)) = parts.split_last() else {
        return false;
    };
    let valid_key = key.len() == 1
        && key
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit());
    let expected = ["primary", "ctrl", "alt", "shift"];
    let mut next_modifier = 0;
    let mut activation_modifier = false;

    for modifier in modifiers {
        let Some(index) = expected.iter().position(|expected| expected == modifier) else {
            return false;
        };
        if index < next_modifier {
            return false;
        }
        next_modifier = index + 1;
        activation_modifier |= matches!(*modifier, "primary" | "ctrl" | "alt");
    }

    !modifiers.is_empty() && activation_modifier && valid_key
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_bounded_canonical_shortcuts() {
        assert!(valid_command("refresh", "primary-shift-r"));
        assert!(!valid_command("refresh", "shift-r"));
        assert!(!valid_command("refresh", "shift-primary-r"));
        assert!(!valid_command("refresh", "primary-R"));
    }

    #[test]
    fn rejects_duplicate_commands() {
        let commands = vec![
            ("first".into(), "primary-a".into()),
            ("first".into(), "primary-b".into()),
        ];
        assert_eq!(
            validate_commands(&commands),
            Err(CommandValidationError::DuplicateId)
        );
    }
}
