use crate::*;

#[cfg(feature = "real-gpui")]
pub(crate) type WindowCommandReply = std::sync::mpsc::SyncSender<Result<(), String>>;

#[cfg(feature = "real-gpui")]
pub(crate) type WindowGenerationReply = std::sync::mpsc::SyncSender<Result<u64, String>>;

#[cfg(feature = "real-gpui")]
#[derive(Clone)]
pub(crate) struct CommandBinding {
    id: String,
    shortcut: gpui::KeybindingKeystroke,
}

#[cfg(feature = "real-gpui")]
impl CommandBinding {
    pub(crate) fn new(id: String, shortcut: String) -> Result<Self, &'static str> {
        if id.is_empty() || id.len() > 128 || !valid_command_shortcut(&shortcut) {
            return Err("invalid_command");
        }

        let shortcut = shortcut
            .split('-')
            .map(|part| if part == "primary" { "secondary" } else { part })
            .collect::<Vec<_>>()
            .join("-");
        let shortcut = gpui::Keystroke::parse(&shortcut).map_err(|_error| "invalid_command")?;
        if !(shortcut.modifiers.platform || shortcut.modifiers.control || shortcut.modifiers.alt) {
            return Err("invalid_command");
        }

        Ok(Self {
            id,
            shortcut: gpui::KeybindingKeystroke::from_keystroke(shortcut),
        })
    }

    fn matches(&self, keystroke: &gpui::Keystroke) -> bool {
        keystroke.should_match(&self.shortcut)
    }
}

#[cfg(feature = "real-gpui")]
fn valid_command_shortcut(shortcut: &str) -> bool {
    if shortcut.is_empty() || shortcut.len() > 64 {
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

#[cfg(feature = "real-gpui")]
fn native_editing_shortcut(keystroke: &gpui::Keystroke) -> bool {
    (keystroke.modifiers.platform || keystroke.modifiers.control)
        && !keystroke.modifiers.alt
        && matches!(keystroke.key.as_str(), "a" | "c" | "v" | "x" | "y" | "z")
}

#[cfg(all(test, feature = "real-gpui"))]
mod command_tests {
    use super::{native_editing_shortcut, valid_command_shortcut, CommandBinding};

    #[test]
    fn primary_shortcuts_use_gpui_platform_matching() {
        let command = CommandBinding::new("refresh".to_string(), "primary-r".to_string())
            .expect("valid command");
        let matching = zed_gpui::Keystroke::parse("secondary-r").expect("valid keystroke");
        let unmodified = zed_gpui::Keystroke::parse("r").expect("valid keystroke");

        assert!(command.matches(&matching));
        assert!(!command.matches(&unmodified));
    }

    #[test]
    fn malformed_native_shortcuts_are_rejected() {
        assert!(valid_command_shortcut("primary-shift-r"));
        assert!(!valid_command_shortcut("shift-r"));
        assert!(!valid_command_shortcut("shift-primary-r"));
        assert!(!valid_command_shortcut("primary-R"));
    }

    #[test]
    fn native_editing_shortcuts_are_reserved_while_an_input_is_focused() {
        let select_all = zed_gpui::Keystroke::parse("ctrl-a").expect("valid keystroke");
        let refresh = zed_gpui::Keystroke::parse("ctrl-r").expect("valid keystroke");

        assert!(native_editing_shortcut(&select_all));
        assert!(!native_editing_shortcut(&refresh));
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) struct WindowState {
    pub(crate) tree: Mutex<ElementNode>,
    commands: Vec<CommandBinding>,
    requested_generation: std::sync::atomic::AtomicU64,
    rendered_generation: std::sync::atomic::AtomicU64,
    scheduled_frame_generation: std::sync::atomic::AtomicU64,
    completed_frame_generation: std::sync::atomic::AtomicU64,
    frame_waiters: Mutex<Vec<(u64, WindowCommandReply)>>,
    next_frame_waiters: Mutex<Vec<(u64, WindowCommandReply)>>,
}

#[cfg(feature = "real-gpui")]
impl WindowState {
    pub(crate) fn new(tree: ElementNode, commands: Vec<CommandBinding>) -> Self {
        Self {
            tree: Mutex::new(tree),
            commands,
            requested_generation: std::sync::atomic::AtomicU64::new(1),
            rendered_generation: std::sync::atomic::AtomicU64::new(0),
            scheduled_frame_generation: std::sync::atomic::AtomicU64::new(0),
            completed_frame_generation: std::sync::atomic::AtomicU64::new(0),
            frame_waiters: Mutex::new(Vec::new()),
            next_frame_waiters: Mutex::new(Vec::new()),
        }
    }
}

#[cfg(feature = "real-gpui")]
pub(crate) type SharedWindow = Arc<WindowState>;

#[cfg(all(feature = "real-gpui", feature = "components"))]
type DialogKeyHandler = Arc<dyn Fn(&gpui::KeyDownEvent, &mut gpui::Window, &mut gpui::App)>;

#[cfg(feature = "real-gpui")]
pub(crate) struct ElixirRoot {
    window_state: SharedWindow,
    pub(crate) runtime: SharedRuntime,
    pub(crate) window_id: u64,
    input_entities: HashMap<String, gpui::Entity<NativeTextInput>>,
    #[cfg(feature = "components")]
    pub(crate) components: crate::element::component_registry::ComponentRegistry,
    command_subscription: Option<gpui::Subscription>,
    observe_commands: bool,
    #[cfg(feature = "components")]
    render_dialog_layer: bool,
    #[cfg(feature = "components")]
    dialog_focus: Option<gpui::FocusHandle>,
    #[cfg(feature = "components")]
    dialog_key_handler: Option<DialogKeyHandler>,
}

#[cfg(feature = "real-gpui")]
impl ElixirRoot {
    pub(crate) fn new(window_state: SharedWindow, runtime: SharedRuntime, window_id: u64) -> Self {
        Self {
            window_state,
            runtime,
            window_id,
            input_entities: HashMap::new(),
            #[cfg(feature = "components")]
            components: crate::element::component_registry::ComponentRegistry::default(),
            command_subscription: None,
            observe_commands: true,
            #[cfg(feature = "components")]
            render_dialog_layer: true,
            #[cfg(feature = "components")]
            dialog_focus: None,
            #[cfg(feature = "components")]
            dialog_key_handler: None,
        }
    }

    #[cfg(feature = "components")]
    pub(crate) fn new_dialog(
        window_state: SharedWindow,
        runtime: SharedRuntime,
        window_id: u64,
        focus: gpui::FocusHandle,
        key_handler: DialogKeyHandler,
    ) -> Self {
        let mut root = Self::new(window_state, runtime, window_id);
        root.render_dialog_layer = false;
        root.observe_commands = false;
        root.dialog_focus = Some(focus);
        root.dialog_key_handler = Some(key_handler);
        root
    }

    fn editable_input_focused(&self, window: &gpui::Window, cx: &gpui::App) -> bool {
        use gpui::Focusable;

        let primitive_input_focused = self
            .input_entities
            .values()
            .any(|input| input.read(cx).focus_handle(cx).is_focused(window));

        #[cfg(feature = "components")]
        let component_input_focused = self.components.editable_input_focused(window, cx);
        #[cfg(not(feature = "components"))]
        let component_input_focused = false;

        primitive_input_focused || component_input_focused
    }

    fn observe_commands(&mut self, window: &gpui::Window, cx: &mut gpui::Context<Self>) {
        if !self.observe_commands
            || self.command_subscription.is_some()
            || self.window_state.commands.is_empty()
        {
            return;
        }

        let expected_window = window.window_handle();
        let commands = self.window_state.commands.clone();
        let runtime = self.runtime.clone();
        let window_id = self.window_id;
        self.command_subscription = Some(cx.observe_keystrokes(move |root, event, window, cx| {
            if window.window_handle() != expected_window
                || (native_editing_shortcut(&event.keystroke)
                    && root.editable_input_focused(window, cx))
            {
                return;
            }

            if let Some(command) = commands
                .iter()
                .find(|command| command.matches(&event.keystroke))
            {
                let _ = push_event(
                    &runtime,
                    NativeEvent::Command {
                        window_id,
                        event: command.id.clone(),
                    },
                );
            }
        }));
    }
}

#[cfg(feature = "real-gpui")]
impl gpui::Render for ElixirRoot {
    fn render(
        &mut self,
        _window: &mut gpui::Window,
        cx: &mut gpui::Context<Self>,
    ) -> impl gpui::IntoElement {
        self.observe_commands(_window, cx);

        let tree = self
            .window_state
            .tree
            .lock()
            .map(|tree| tree.clone())
            .unwrap_or_else(|_| ElementNode::empty_root());
        let mut active_input_ids = HashSet::new();
        #[cfg(feature = "components")]
        self.components.begin_render();
        let element = tree.render(&mut ElementRenderContext {
            runtime: self.runtime.clone(),
            window_id: self.window_id,
            next_element_id: 0,
            id_namespace: "root".to_string(),
            active_input_ids: &mut active_input_ids,
            input_entities: &mut self.input_entities,
            #[cfg(feature = "components")]
            components: &mut self.components,
            window: _window,
            cx,
        });
        self.input_entities
            .retain(|input_id, _entity| active_input_ids.contains(input_id));
        #[cfg(feature = "components")]
        self.components.finish_render(_window, cx);

        let input_prefix = format!("gpui-elixir-input-{}-root-", self.window_id);
        if let Ok(mut input_values) = self.runtime.input_values.lock() {
            input_values.retain(|input_id, _value| {
                !input_id.starts_with(&input_prefix) || active_input_ids.contains(input_id)
            });
        }

        #[cfg(feature = "components")]
        if self.render_dialog_layer {
            use gpui::{IntoElement, ParentElement};

            let element = gpui::div()
                .child(element)
                .children(gpui_component::Root::render_dialog_layer(_window, cx))
                .into_any_element();
            return acknowledge_frame(element, self.window_state.clone());
        }

        #[cfg(feature = "components")]
        if let (Some(focus), Some(key_handler)) =
            (self.dialog_focus.clone(), self.dialog_key_handler.clone())
        {
            use gpui::{InteractiveElement, IntoElement, ParentElement};

            let element = gpui::div()
                .id("gpui-elixir-dialog-content")
                .track_focus(&focus.tab_stop(true))
                .on_key_down(move |event, window, cx| key_handler(event, window, cx))
                .child(element)
                .into_any_element();
            return acknowledge_frame(element, self.window_state.clone());
        }

        acknowledge_frame(element, self.window_state.clone())
    }
}

#[cfg(feature = "real-gpui")]
fn acknowledge_frame(element: gpui::AnyElement, window_state: SharedWindow) -> gpui::AnyElement {
    use gpui::{IntoElement, ParentElement, Styled};
    use std::sync::atomic::Ordering;

    let barrier = gpui::canvas(
        move |_bounds, window, _cx| {
            let generation = window_state.requested_generation.load(Ordering::Acquire);
            let frame_generation = window_state
                .scheduled_frame_generation
                .fetch_add(1, Ordering::AcqRel)
                + 1;
            let window_state = window_state.clone();
            window.on_next_frame(move |_window, _cx| {
                complete_frame(&window_state, generation, frame_generation)
            });
        },
        |_bounds, _prepaint, _window, _cx| {},
    )
    .absolute()
    .size_full();

    gpui::div()
        .relative()
        .size_full()
        .child(barrier)
        .child(element)
        .into_any_element()
}

#[cfg(feature = "real-gpui")]
fn complete_frame(window_state: &SharedWindow, generation: u64, frame_generation: u64) {
    use std::sync::atomic::Ordering;

    window_state
        .rendered_generation
        .fetch_max(generation, Ordering::AcqRel);
    window_state
        .completed_frame_generation
        .fetch_max(frame_generation, Ordering::AcqRel);

    complete_waiters(&window_state.frame_waiters, generation);
    complete_waiters(&window_state.next_frame_waiters, frame_generation);
}

#[cfg(feature = "real-gpui")]
fn complete_waiters(waiters: &Mutex<Vec<(u64, WindowCommandReply)>>, generation: u64) {
    if let Ok(mut waiters) = waiters.lock() {
        let mut pending = Vec::new();
        for (target, reply) in std::mem::take(&mut *waiters) {
            if target <= generation {
                send_reply(reply, Ok(()));
            } else {
                pending.push((target, reply));
            }
        }
        *waiters = pending;
    }
}

#[cfg(feature = "real-gpui")]
fn await_generation(
    completed: &std::sync::atomic::AtomicU64,
    waiters: &Mutex<Vec<(u64, WindowCommandReply)>>,
    target: u64,
    reply: WindowCommandReply,
) {
    use std::sync::atomic::Ordering;

    if completed.load(Ordering::Acquire) >= target {
        send_reply(reply, Ok(()));
        return;
    }

    match waiters.lock() {
        Ok(mut waiters) => {
            if completed.load(Ordering::Acquire) >= target {
                send_reply(reply, Ok(()));
            } else {
                waiters.push((target, reply));
            }
        }
        Err(_error) => send_reply(reply, Err("runtime_lock_failed".to_string())),
    }
}

#[cfg(feature = "real-gpui")]
#[derive(Clone, Copy)]
pub(crate) enum NativeThemeMode {
    Light,
    Dark,
}

#[cfg(feature = "real-gpui")]
pub(crate) enum WindowCommand {
    Open {
        runtime_id: u64,
        title: String,
        window_id: u64,
        width: f32,
        height: f32,
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
    AwaitFrame {
        runtime_id: u64,
        window_id: u64,
        reply: WindowCommandReply,
    },
    FrameToken {
        runtime_id: u64,
        window_id: u64,
        reply: WindowGenerationReply,
    },
    AwaitFrameAfter {
        runtime_id: u64,
        window_id: u64,
        generation: u64,
        reply: WindowCommandReply,
    },
    ShutdownRuntime {
        runtime_id: u64,
        reply: Option<WindowCommandReply>,
    },
    SetTheme {
        mode: NativeThemeMode,
        reply: WindowCommandReply,
    },
    PlatformClosed {
        platform_id: gpui::WindowId,
    },
}

#[cfg(all(feature = "real-gpui", feature = "components"))]
type NativeWindowRoot = gpui_component::Root;

#[cfg(all(feature = "real-gpui", not(feature = "components")))]
type NativeWindowRoot = ElixirRoot;

#[cfg(feature = "real-gpui")]
struct ManagedWindow {
    handle: gpui::WindowHandle<NativeWindowRoot>,
    view: gpui::Entity<ElixirRoot>,
    state: SharedWindow,
    runtime: SharedRuntime,
}

#[cfg(feature = "real-gpui")]
type WindowKey = (u64, u64);

#[cfg(feature = "real-gpui")]
pub(crate) fn run_gpui(
    mut commands: mpsc::UnboundedReceiver<WindowCommand>,
    command_tx: mpsc::UnboundedSender<WindowCommand>,
    ready: std::sync::mpsc::SyncSender<Result<(), &'static str>>,
) {
    use gpui::App;

    let application = gpui_platform::application().with_quit_mode(gpui::QuitMode::Explicit);

    #[cfg(feature = "components")]
    let application = application.with_assets(gpui_component_assets::Assets);

    application.run(move |cx: &mut App| {
        #[cfg(feature = "components")]
        gpui_component::init(cx);

        bind_input_keys(cx);

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
        let _ = ready.send(Ok(()));
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
            width,
            height,
            window_state,
            runtime,
            reply,
        } => {
            let key = (runtime_id, window_id);
            if let Some(window) = windows.remove(&key) {
                let _ = close_managed_window(window, cx);
            }

            let result = open_gpui_window(
                title,
                window_id,
                width,
                height,
                window_state.clone(),
                runtime.clone(),
                cx,
            )
            .map(|(handle, view)| {
                windows.insert(
                    key,
                    ManagedWindow {
                        handle,
                        view,
                        state: window_state,
                        runtime,
                    },
                );
            });
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
        WindowCommand::AwaitFrame {
            runtime_id,
            window_id,
            reply,
        } => await_gpui_frame(windows, (runtime_id, window_id), reply, cx),
        WindowCommand::FrameToken {
            runtime_id,
            window_id,
            reply,
        } => gpui_frame_token(windows, (runtime_id, window_id), reply),
        WindowCommand::AwaitFrameAfter {
            runtime_id,
            window_id,
            generation,
            reply,
        } => await_gpui_frame_after(windows, (runtime_id, window_id), generation, reply),
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
        WindowCommand::SetTheme { mode, reply } => {
            let result = set_component_theme(mode, windows, cx);
            send_reply(reply, result);
        }
        WindowCommand::PlatformClosed { platform_id } => {
            handle_platform_window_closed(windows, platform_id);
        }
    }
}

#[cfg(feature = "components")]
fn set_component_theme(
    mode: NativeThemeMode,
    windows: &mut HashMap<WindowKey, ManagedWindow>,
    cx: &mut gpui::App,
) -> Result<(), String> {
    let mode = match mode {
        NativeThemeMode::Light => gpui_component::ThemeMode::Light,
        NativeThemeMode::Dark => gpui_component::ThemeMode::Dark,
    };
    gpui_component::Theme::change(mode, None, cx);

    windows.values().try_for_each(|window| {
        window
            .handle
            .update(cx, |_root, native_window, _cx| native_window.refresh())
            .map_err(|error| error.to_string())
    })
}

#[cfg(all(feature = "real-gpui", not(feature = "components")))]
fn set_component_theme(
    _mode: NativeThemeMode,
    _windows: &mut HashMap<WindowKey, ManagedWindow>,
    _cx: &mut gpui::App,
) -> Result<(), String> {
    Err("components_disabled".to_string())
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
        .state
        .requested_generation
        .fetch_add(1, std::sync::atomic::Ordering::AcqRel);

    let view = window.view.clone();

    let result = window.handle.update(cx, |_root, native_window, cx| {
        native_window.defer(cx, move |native_window, cx| {
            view.update(cx, |_view, cx| cx.notify());
            native_window.refresh();
            cx.refresh_windows();
        });
    });
    result.map_err(|error| error.to_string())
}

#[cfg(feature = "real-gpui")]
fn await_gpui_frame(
    windows: &HashMap<WindowKey, ManagedWindow>,
    key: WindowKey,
    reply: WindowCommandReply,
    _cx: &mut gpui::App,
) {
    use std::sync::atomic::Ordering;

    let Some(window) = windows.get(&key) else {
        send_reply(reply, Err("unknown_window".to_string()));
        return;
    };

    let target = window.state.requested_generation.load(Ordering::Acquire);
    await_generation(
        &window.state.rendered_generation,
        &window.state.frame_waiters,
        target,
        reply,
    );
}

#[cfg(feature = "real-gpui")]
fn gpui_frame_token(
    windows: &HashMap<WindowKey, ManagedWindow>,
    key: WindowKey,
    reply: WindowGenerationReply,
) {
    use std::sync::atomic::Ordering;

    let result = windows
        .get(&key)
        .map(|window| {
            window
                .state
                .completed_frame_generation
                .load(Ordering::Acquire)
        })
        .ok_or_else(|| "unknown_window".to_string());
    let _ = reply.send(result);
}

#[cfg(feature = "real-gpui")]
fn await_gpui_frame_after(
    windows: &HashMap<WindowKey, ManagedWindow>,
    key: WindowKey,
    generation: u64,
    reply: WindowCommandReply,
) {
    let Some(window) = windows.get(&key) else {
        send_reply(reply, Err("unknown_window".to_string()));
        return;
    };

    await_generation(
        &window.state.completed_frame_generation,
        &window.state.next_frame_waiters,
        generation.saturating_add(1),
        reply,
    );
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
    width: f32,
    height: f32,
    window_state: SharedWindow,
    runtime: SharedRuntime,
    cx: &mut gpui::App,
) -> Result<
    (
        gpui::WindowHandle<NativeWindowRoot>,
        gpui::Entity<ElixirRoot>,
    ),
    String,
> {
    use gpui::{px, size, AppContext, Bounds, WindowBounds, WindowOptions};

    let bounds = Bounds::centered(None, size(px(width), px(height)), cx);
    let view = cx.new(|_cx| ElixirRoot::new(window_state, runtime, window_id));
    let view_for_root = view.clone();

    let handle = cx
        .open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |native_window, cx| {
                native_window.set_window_title(&title);
                native_window_root(view_for_root.clone(), native_window, cx)
            },
        )
        .map_err(|error| error.to_string())?;

    Ok((handle, view))
}

#[cfg(feature = "components")]
fn native_window_root(
    view: gpui::Entity<ElixirRoot>,
    native_window: &mut gpui::Window,
    cx: &mut gpui::App,
) -> gpui::Entity<NativeWindowRoot> {
    use gpui::AppContext;

    cx.new(|cx| gpui_component::Root::new(view, native_window, cx))
}

#[cfg(not(feature = "components"))]
fn native_window_root(
    view: gpui::Entity<ElixirRoot>,
    _native_window: &mut gpui::Window,
    _cx: &mut gpui::App,
) -> gpui::Entity<NativeWindowRoot> {
    view
}
