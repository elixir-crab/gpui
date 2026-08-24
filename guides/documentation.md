# GPUI documentation

GPUI keeps application state and declarative UI policy in Elixir while native
displays interpret immutable snapshots. Choose a path below based on what you
are trying to do.

## Build an application

1. Start with [Your first application](first-application.html).
2. Learn the runtime model in
   [Sessions, snapshots, and displays](sessions-snapshots-and-displays.html).
3. Browse [UI components](components.html),
   [Commands and keyboard shortcuts](commands-and-shortcuts.html), and
   [Overlays and menus](overlays-and-menus.html).
4. Add coverage with [Testing GPUI applications](overview.html).

## Use framework capabilities

- [Remote displays](remote-displays.html) connects an application session to a
  display in another process or machine.
- [Native builds and deployment](native-builds.html) covers source builds,
  feature sets, and release validation.
- [Presentation primitives](presentation-primitives.html) explains bounded edge
  fades, frost fallbacks, and custom paint for application authors.
- [Test coverage ownership](coverage-ownership.html) identifies which test tier
  owns each kind of behavior.

## Contribute to GPUI

These documents describe implementation boundaries rather than the normal
application-authoring workflow:

- [Platform support and development status](platform-support.html)
- [Editable text internals](editable-text.html)
- [Native text projections](text-projections.html)
- [Accessibility](accessibility.html)
- [Transfer payloads](transfers.html)
- [Presentation extension contracts](presentation-contracts.html)
- [Declarative motion decision](declarative-motion.html)
- [Window chrome decision](window-chrome.html)

The project is private and unreleased. Internal payloads may change directly;
version fields detect mismatched running components rather than promise support
for historical revisions.
