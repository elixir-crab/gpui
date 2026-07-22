# Git Repository Browser

This substantial example browses a server-local Git working tree with a
hierarchical virtualized file list and a source-backed monospaced file or diff
viewer.

Run it from the repository root:

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/git_repository_browser/run.exs -- path/to/repository
```

When no path is supplied, it opens the current repository.

## What it demonstrates

- supervised and cancellable repository scans and previews;
- bounded Git command output and bounded regular-file reads;
- status and path filtering across large repositories;
- an accessible expandable hierarchy backed by source-backed `GPUI.UI.tree/1`;
- stable file and directory identities;
- source-owned repository and preview models, so snapshots contain only loaded slices;
- `GPUI.UI.code_viewer/1` with line selection, display-side copying, horizontal
  scrolling, and distinct added, deleted, context, and hunk rows;
- operation generations that prevent stale scans or previews from winning;
- `primary-r` repository refresh and `primary-f` filter-focus commands;
- deterministic application, repository, and visual tests.

## Filesystem semantics

The path belongs to the machine running the Elixir application. This is
intentional and differs from `GPUI.UI.file_picker/1`, whose selected bytes come
from the display machine. A remote display can browse a repository available to
the application server, but this example does not claim access to directories
on the remote client.

The example invokes `git` directly through an OTP port without a shell. Scan
output is capped at 20 MiB. Diff and file previews are capped at 1 MiB and
20,000 lines; symlinks and non-regular working-tree entries are not followed for
content previews. The coordinator retains those bounded models and responds to
native range requests with small contiguous tree and preview slices.
