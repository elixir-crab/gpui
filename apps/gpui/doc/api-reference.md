# gpui v0.2.0-rc.2 - API Reference

## Modules

- [GPUI.Accessibility](GPUI.Accessibility.md): Bounded renderer-independent accessibility contracts for generic elements.
- [GPUI.Color](GPUI.Color.md): Compile-time hexadecimal RGB and RGBA color literals.
- [GPUI.Native](GPUI.Native.md): Availability information for the optional native GPUI backend.
- [GPUI.Schema](GPUI.Schema.md): Canonical element, component, event, resource, and style protocol schema.
- [GPUI.Schema.Component](GPUI.Schema.Component.md): Declarative schema for one renderer-native element or UI component.
- [GPUI.Schema.Registry](GPUI.Schema.Registry.md): Immutable composition of explicitly selected declarative schema modules.
- [GPUI.Text.RichRun](GPUI.Text.RichRun.md): A neutral shaping run for immutable rich text.
- [GPUI.Text.StyleRun](GPUI.Text.StyleRun.md): A neutral shaping style applied to a logical text range.
- [GPUI.Transfer.Event](GPUI.Transfer.Event.md): A bounded renderer-independent drag/drop event fact.
- [GPUI.Transfer.Payload](GPUI.Transfer.Payload.md): Bounded renderer-independent clipboard or drag/drop facts.

- Core
  - [GPUI](GPUI.md): Elixir-facing entry point for GPUI applications and views.
  - [GPUI.Application](GPUI.Application.md): Behaviour and DSL for OTP-supervised GPUI applications.
  - [GPUI.Application.Icon](GPUI.Application.Icon.md): Application-owned icon source metadata.
  - [GPUI.Application.Identity](GPUI.Application.Identity.md): Stable process-wide identity for a GPUI application.
  - [GPUI.Builder](GPUI.Builder.md): Programmatic builders for immutable `GPUI.Element` trees.
  - [GPUI.Command](GPUI.Command.md): Declarative application command bound to a modified keyboard shortcut.
  - [GPUI.Debug](GPUI.Debug.md): Renderer-independent inspection of authoritative GPUI snapshots and trees.
  - [GPUI.Dev.Reload](GPUI.Dev.Reload.md): Development-time source reloading for a running GPUI runtime.
  - [GPUI.Runtime](GPUI.Runtime.md): Primary application-facing process API for one GPUI application and display.
  - [GPUI.Runtime.Error](GPUI.Runtime.Error.md): Exception raised by a bang runtime operation when its non-bang form returns an error.
  - [GPUI.Runtime.Update](GPUI.Runtime.Update.md): A synchronized runtime update delivered to `GPUI.Runtime` subscribers.
  - [GPUI.Snapshot](GPUI.Snapshot.md): Renderer-independent snapshot of a running `GPUI.Session`.
  - [GPUI.Snapshot.Window](GPUI.Snapshot.Window.md): Typed shape of one serialized window in a `GPUI.Snapshot`.
  - [GPUI.Tree](GPUI.Tree.md): Renderer-independent queries over `GPUI.Element` and serialized element trees.
  - [GPUI.View](GPUI.View.md): Behaviour for Elixir-rendered GPUI views.

- Advanced infrastructure
  - [GPUI.Session](GPUI.Session.md): Renderer-independent state engine for one running `GPUI.Application`.

- Text
  - [GPUI.Text.BlockProjection](GPUI.Text.BlockProjection.md): A non-editable block rendered adjacent to an explicit logical text line.
  - [GPUI.Text.Buffer](GPUI.Text.Buffer.md): Persistent native Rope text storage with revisioned atomic edits.
  - [GPUI.Text.CaretGeometry](GPUI.Text.CaretGeometry.md): Window-relative native pixel bounds for a text surface's primary caret.
  - [GPUI.Text.Decoration](GPUI.Text.Decoration.md): A neutral visual annotation attached to a logical text range.
  - [GPUI.Text.Edit](GPUI.Text.Edit.md): An atomic replacement of one half-open text range.
  - [GPUI.Text.InlineProjection](GPUI.Text.InlineProjection.md): Non-editable text rendered at an explicit logical text position.
  - [GPUI.Text.Position](GPUI.Text.Position.md): A zero-based logical text position.
  - [GPUI.Text.Range](GPUI.Text.Range.md): A half-open range between two `GPUI.Text.Position` values.
  - [GPUI.Text.RangeGeometry](GPUI.Text.RangeGeometry.md): Window-relative native pixel bounds for one requested logical text range.
  - [GPUI.Text.Rectangle](GPUI.Text.Rectangle.md): Window-relative native pixel rectangle for laid-out text.
  - [GPUI.Text.Selection](GPUI.Text.Selection.md): A directed selection represented by anchor and head positions.
  - [GPUI.Text.Snapshot](GPUI.Text.Snapshot.md): An immutable snapshot of a persistent native text buffer.
  - [GPUI.Text.Transaction](GPUI.Text.Transaction.md): A revisioned atomic set of text edits and resulting selections.
  - [GPUI.Text.Transaction.Result](GPUI.Text.Transaction.Result.md): Result of applying a `GPUI.Text.Transaction` to a persistent text buffer.
  - [GPUI.Text.Viewport](GPUI.Text.Viewport.md): A revision-tagged snapshot of one text surface's visible visual rows.

- Displays
  - [GPUI.Display](GPUI.Display.md): Behaviour for displays that present GPUI snapshots and return input events.

- Elements
  - [GPUI.Element](GPUI.Element.md): Serializable element tree produced by `GPUI.View` modules.

  - [GPUI.Event](GPUI.Event.md): Normalized UI event delivered from a display into `GPUI.Session`.

  - [GPUI.Raster](GPUI.Raster.md): Generic packed 32-bit CPU raster image payload for GPUI image elements.
  - [GPUI.ResourceRef](GPUI.ResourceRef.md): Reference to a remote/display resource such as a raster image.

  - [GPUI.Schema.Extension](GPUI.Schema.Extension.md): Compile-time metadata for one versioned renderer presentation contract.
  - [GPUI.Schema.Extension.Support](GPUI.Schema.Extension.Support.md): Bounded display support for one exact presentation contract version.
  - [GPUI.Tailwind](GPUI.Tailwind.md): Small Tailwind-compatible class normalizer for GPUI element styles.
  - [GPUI.Template](GPUI.Template.md): HEEx-style template support for GPUI.
  - [GPUI.WindowSpec](GPUI.WindowSpec.md): Declarative window specification returned by the application DSL.

- Remote
  - [GPUI.Remote.Client](GPUI.Remote.Client.md): Display-side client for a remote GPUI application session.
  - [GPUI.Remote.Server](GPUI.Remote.Server.md): SafeRPC endpoint for renderer-independent GPUI application sessions.

- Testing
  - [GPUI.Test](GPUI.Test.md): ExUnit helpers for renderer-independent application tests and deterministic
GPUI interaction tests.
  - [GPUI.Test.Display](GPUI.Test.Display.md): Deterministic in-memory display for session and runtime tests.
  - [GPUI.Test.UI](GPUI.Test.UI.md): An opaque interactive UI handle supplied by `use GPUI.Test, native: ...`.

