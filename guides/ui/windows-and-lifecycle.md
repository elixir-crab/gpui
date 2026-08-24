# Windows and lifecycle

Window topology remains application-owned. Window specifications declare
platform constraints, while optional view callbacks decide how lifecycle
requests affect application state.

## Window lifecycle

Window declarations contain only declarative platform constraints:

```elixir
window "Workspace" do
  size 1100, 720
  min_size 760, 480
  resizable true
  chrome :content
  root WorkspaceView
end
```

Views opt into lifecycle handling through an idiomatic optional behaviour
callback rather than arbitrary routing strings:

```elixir
def handle_window_event(:close_request, _event, assigns) do
  {:noreply, %{assigns | close_dialog_open: true}}
end

def handle_window_event(:focus, _event, assigns) do
  {:noreply, %{assigns | window_active: true}}
end

def handle_window_event(:blur, _event, assigns) do
  {:noreply, %{assigns | window_active: false}}
end
```

Exporting `handle_window_event/3` enables interception and activation delivery
for the view's window. A close request remains asynchronous. Return
`{:noreply, assigns}` to keep the window open—for example while rendering an
application-owned confirmation dialog—or `{:close, assigns}` to approve closure.
Ordinary `handle_event/3` handlers may also return `{:close, assigns}` after a
confirmation action.

`min_size`, `resizable`, and `chrome` are declarative creation options interpreted by the
native display. `chrome :system` is the default; `chrome :content` extends
application content into native chrome and enables ordinary containers marked
with `window_control="drag|close|maximize|minimize"`. Creation-option changes
reopen the native window while retaining its session ID. See
[Decision: declarative native window chrome](window-chrome.html)
for platform behavior and fallback rules. The existing `:window_closed` event remains an internal final
notification after a window actually closes. Window `:focus` and `:blur`
callbacks report native activation and are separate from element focus.
