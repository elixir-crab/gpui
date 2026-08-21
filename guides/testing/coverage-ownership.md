# Test coverage ownership

GPUI behavior is divided by what each layer can truthfully prove.

| Behavior | Renderer-independent ExUnit | Deterministic native ExUnit | Desktop E2E |
| --- | --- | --- | --- |
| Controlled application state and rerenders | Primary | Exercises real payload rerenders | Smoke only |
| Switch and radio activation | Event policy | Pointer, focus, keyboard, disabled/loading | Real window rendering |
| Tabs | Controlled event handling | Stable bounds, focus, keyboard, disabled | Real window rendering |
| Accordion | Controlled expanded IDs and validation | Stable bounds, pointer toggles, controlled multiple expansion, disabled-group suppression | Real window rendering |
| Tree and data table navigation | Source/state policy | Focus, keyboard, disabled skipping, emitted IDs | Virtualized real window and pointer delivery |
| Uniform and variable collections | Range/source policy | Selection, ranges, scrolling, transitions | Compositor range and wheel delivery |
| Dialog and overlays | Controlled open/close policy | Stable dialog-trigger bounds and keyboard open request; Escape policy has Rust unit coverage; headless top-layer focus remains blocked by `gpui-component::Root` | Window/top-layer focus containment, closure, and restoration |
| Rich text | Runs, ranges, links, controlled events | Shaping and link-navigation Rust unit coverage; stable public target pending | Real shaped rendering |
| Persistent editable text | Buffer, revisions, transactions | Blocked by `InputState` requiring a platform window handle | Native typing, IME, selection and clipboard |
| Clipboard and external transfer | Bounded payload and event policy | Boundary/routing unit coverage | OS clipboard and external transfer facts |
| Remote display | Protocol, synchronization and reconnect policy | Not applicable | Real remote-native window smoke |
| Pixel appearance and contrast | Not applicable | Not a behavioral assertion | Synchronized visual capture |

When moving an assertion between layers, preserve the behavior in its owning layer.
Do not retain coordinate-heavy desktop assertions for component mechanics already
covered deterministically. Conversely, deterministic tests must not claim OS
clipboard, IME, compositor, accessibility-adapter, or external-drop behavior.
