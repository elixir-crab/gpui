use crate::*;

#[cfg(feature = "real-gpui")]
pub(crate) struct WindowState {
    pub(crate) tree: Mutex<ElementNode>,
}

#[cfg(feature = "real-gpui")]
pub(crate) type SharedWindow = Arc<WindowState>;

#[cfg(feature = "real-gpui")]
pub(crate) struct ElixirRoot {
    window_state: SharedWindow,
    runtime: SharedRuntime,
    window_id: u64,
    input_entities: HashMap<String, gpui::Entity<NativeTextInput>>,
}

#[cfg(feature = "real-gpui")]
impl gpui::Render for ElixirRoot {
    fn render(
        &mut self,
        _window: &mut gpui::Window,
        cx: &mut gpui::Context<Self>,
    ) -> impl gpui::IntoElement {
        let tree = self
            .window_state
            .tree
            .lock()
            .map(|tree| tree.clone())
            .unwrap_or_else(|_| ElementNode::empty_root());
        tree.render(&mut ElementRenderContext {
            runtime: self.runtime.clone(),
            window_id: self.window_id,
            input_entities: &mut self.input_entities,
            cx,
        })
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) type WindowCommandReply = std::sync::mpsc::SyncSender<Result<(), String>>;

#[cfg(feature = "real-gpui")]
pub(crate) enum WindowCommand {
    Open {
        runtime_id: u64,
        title: String,
        window_id: u64,
        window_state: SharedWindow,
        runtime: SharedRuntime,
        reply: WindowCommandReply,
    },
    Update {
        runtime_id: u64,
        window_id: u64,
        tree: Box<ElementNode>,
        reply: WindowCommandReply,
    },
    Close {
        runtime_id: u64,
        window_id: u64,
        reply: WindowCommandReply,
    },
    ShutdownRuntime {
        runtime_id: u64,
        reply: Option<WindowCommandReply>,
    },
    PlatformClosed {
        platform_id: gpui::WindowId,
    },
}

#[cfg(feature = "real-gpui")]
struct ManagedWindow {
    handle: gpui::WindowHandle<ElixirRoot>,
    state: SharedWindow,
    runtime: SharedRuntime,
}

#[cfg(feature = "real-gpui")]
type WindowKey = (u64, u64);

#[cfg(feature = "real-gpui")]
pub(crate) fn run_gpui(
    mut commands: mpsc::UnboundedReceiver<WindowCommand>,
    command_tx: mpsc::UnboundedSender<WindowCommand>,
) {
    use gpui::App;

    gpui_platform::application()
        .with_quit_mode(gpui::QuitMode::Explicit)
        .run(move |cx: &mut App| {
            let window_closed_subscription = cx.on_window_closed(move |_cx, platform_id| {
                let _ = command_tx.unbounded_send(WindowCommand::PlatformClosed { platform_id });
            });

            cx.spawn(async move |cx| {
                let _window_closed_subscription = window_closed_subscription;
                let mut windows = HashMap::<WindowKey, ManagedWindow>::new();

                while let Some(command) = commands.next().await {
                    cx.update(|cx| handle_window_command(command, &mut windows, cx));
                }
            })
            .detach();

            cx.activate(true);
        });
}

#[cfg(feature = "real-gpui")]
fn handle_window_command(
    command: WindowCommand,
    windows: &mut HashMap<WindowKey, ManagedWindow>,
    cx: &mut gpui::App,
) {
    match command {
        WindowCommand::Open {
            runtime_id,
            title,
            window_id,
            window_state,
            runtime,
            reply,
        } => {
            let key = (runtime_id, window_id);
            if let Some(window) = windows.remove(&key) {
                let _ = close_managed_window(window, cx);
            }

            let result =
                open_gpui_window(title, window_id, window_state.clone(), runtime.clone(), cx).map(
                    |handle| {
                        windows.insert(
                            key,
                            ManagedWindow {
                                handle,
                                state: window_state,
                                runtime,
                            },
                        );
                    },
                );
            send_reply(reply, result);
        }
        WindowCommand::Update {
            runtime_id,
            window_id,
            tree,
            reply,
        } => {
            let result = update_gpui_window(windows, (runtime_id, window_id), *tree, cx);
            send_reply(reply, result);
        }
        WindowCommand::Close {
            runtime_id,
            window_id,
            reply,
        } => {
            let result = close_gpui_window(windows, (runtime_id, window_id), cx);
            send_reply(reply, result);
        }
        WindowCommand::ShutdownRuntime { runtime_id, reply } => {
            let keys = windows
                .keys()
                .filter(|(owner_id, _window_id)| *owner_id == runtime_id)
                .copied()
                .collect::<Vec<_>>();

            let result = keys
                .into_iter()
                .try_for_each(|key| close_gpui_window(windows, key, cx));

            if let Some(reply) = reply {
                send_reply(reply, result);
            }
        }
        WindowCommand::PlatformClosed { platform_id } => {
            handle_platform_window_closed(windows, platform_id);
        }
    }
}

#[cfg(feature = "real-gpui")]
fn handle_platform_window_closed(
    windows: &mut HashMap<WindowKey, ManagedWindow>,
    platform_id: gpui::WindowId,
) {
    let key = windows
        .iter()
        .find_map(|(key, window)| (window.handle.window_id() == platform_id).then_some(*key));

    if let Some(key) = key {
        if let Some(window) = windows.remove(&key) {
            let _ = push_event(
                &window.runtime,
                NativeEvent::WindowClosed { window_id: key.1 },
            );
        }
    }
}

#[cfg(feature = "real-gpui")]
fn send_reply(reply: WindowCommandReply, result: Result<(), String>) {
    let _ = reply.send(result);
}

#[cfg(feature = "real-gpui")]
fn update_gpui_window(
    windows: &mut HashMap<WindowKey, ManagedWindow>,
    key: WindowKey,
    tree: ElementNode,
    cx: &mut gpui::App,
) -> Result<(), String> {
    let window = windows
        .get(&key)
        .ok_or_else(|| "unknown_window".to_string())?;
    *window
        .state
        .tree
        .lock()
        .map_err(|_| "runtime_lock_failed".to_string())? = tree;

    window
        .handle
        .update(cx, |_root, native_window, cx| {
            cx.notify();
            native_window.refresh();
        })
        .map_err(|error| error.to_string())
}

#[cfg(feature = "real-gpui")]
fn close_gpui_window(
    windows: &mut HashMap<WindowKey, ManagedWindow>,
    key: WindowKey,
    cx: &mut gpui::App,
) -> Result<(), String> {
    let window = windows
        .remove(&key)
        .ok_or_else(|| "unknown_window".to_string())?;
    let runtime = window.runtime.clone();
    close_managed_window(window, cx)?;
    push_event(&runtime, NativeEvent::WindowClosed { window_id: key.1 })
        .map_err(|_error| "runtime_lock_failed".to_string())
}

#[cfg(feature = "real-gpui")]
fn close_managed_window(window: ManagedWindow, cx: &mut gpui::App) -> Result<(), String> {
    window
        .handle
        .update(cx, |_root, native_window, _cx| {
            native_window.remove_window()
        })
        .map_err(|error| error.to_string())
}

#[cfg(feature = "real-gpui")]
fn open_gpui_window(
    title: String,
    window_id: u64,
    window_state: SharedWindow,
    runtime: SharedRuntime,
    cx: &mut gpui::App,
) -> Result<gpui::WindowHandle<ElixirRoot>, String> {
    use gpui::{px, size, AppContext, Bounds, WindowBounds, WindowOptions};

    let bounds = Bounds::centered(None, size(px(500.0), px(500.0)), cx);
    let window_state_for_view = window_state.clone();
    let runtime_for_view = runtime.clone();

    cx.open_window(
        WindowOptions {
            window_bounds: Some(WindowBounds::Windowed(bounds)),
            ..Default::default()
        },
        |native_window, cx| {
            native_window.set_window_title(&title);
            cx.new(|_cx| ElixirRoot {
                window_state: window_state_for_view.clone(),
                runtime: runtime_for_view.clone(),
                window_id,
                input_entities: HashMap::new(),
            })
        },
    )
    .map_err(|error| error.to_string())
}
