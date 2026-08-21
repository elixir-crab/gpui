use std::sync::atomic::{AtomicBool, Ordering};

#[cfg(feature = "native-test")]
use crate::*;
#[cfg(feature = "native-test")]
use std::sync::Arc;

#[cfg(feature = "native-test")]
const COMMAND_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(5);
#[cfg(feature = "native-test")]
const MAX_PENDING_COMMANDS: usize = 64;

#[cfg(not(feature = "native-test"))]
pub(crate) struct TestBounds {
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) width: f64,
    pub(crate) height: f64,
}

#[cfg(feature = "native-test")]
type TestCommandReply<T> = std::sync::mpsc::SyncSender<Result<T, String>>;

#[cfg(feature = "native-test")]
enum TestCommand {
    Render {
        tree: Box<ElementNode>,
        reply: TestCommandReply<()>,
    },
    Focus {
        component_id: String,
        reply: TestCommandReply<()>,
    },
    Click {
        element_id: &'static str,
        reply: TestCommandReply<()>,
    },
    ClickAt {
        x: f32,
        y: f32,
        reply: TestCommandReply<()>,
    },
    Scroll {
        element_id: &'static str,
        delta_x: f32,
        delta_y: f32,
        reply: TestCommandReply<()>,
    },
    Input {
        text: String,
        reply: TestCommandReply<()>,
    },
    Resize {
        width: f32,
        height: f32,
        reply: TestCommandReply<()>,
    },
    Bounds {
        element_id: &'static str,
        reply: TestCommandReply<TestBounds>,
    },
    Idle {
        reply: TestCommandReply<()>,
    },
    Advance {
        milliseconds: u64,
        reply: TestCommandReply<()>,
    },
    Key {
        key: String,
        reply: TestCommandReply<()>,
    },
    Events {
        reply: TestCommandReply<Vec<NativeEvent>>,
    },
    Stop {
        reply: Option<TestCommandReply<()>>,
    },
}

pub(crate) struct NativeTestSessionResource {
    #[cfg(feature = "native-test")]
    commands: std::sync::mpsc::SyncSender<TestCommand>,
    stopped: AtomicBool,
    #[cfg(feature = "native-test")]
    selector_names: std::sync::Mutex<std::collections::HashMap<String, &'static str>>,
}

#[rustler::resource_impl]
impl rustler::Resource for NativeTestSessionResource {}

impl Drop for NativeTestSessionResource {
    fn drop(&mut self) {
        if !self.stopped.swap(true, Ordering::AcqRel) {
            #[cfg(feature = "native-test")]
            let _ = self.commands.try_send(TestCommand::Stop { reply: None });
        }
    }
}

#[cfg(feature = "native-test")]
struct TestSession {
    runtime: SharedRuntime,
    view: gpui::Entity<ElixirRoot>,
    context: gpui::VisualTestContext,
}

#[cfg(feature = "native-test")]
#[derive(Clone, Copy)]
pub(crate) struct TestBounds {
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) width: f64,
    pub(crate) height: f64,
}

#[cfg(feature = "native-test")]
fn execute<T>(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    build: impl FnOnce(TestCommandReply<T>) -> TestCommand,
) -> Result<T, String> {
    if session.stopped.load(Ordering::Acquire) {
        return Err("native_test_worker_stopped".to_string());
    }

    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    session.commands.try_send(build(reply)).map_err(|error| {
        if matches!(error, std::sync::mpsc::TrySendError::Full(_)) {
            "native_test_busy".to_string()
        } else {
            session.stopped.store(true, Ordering::Release);
            "native_test_worker_stopped".to_string()
        }
    })?;

    receiver.recv_timeout(COMMAND_TIMEOUT).map_err(|error| {
        if matches!(error, std::sync::mpsc::RecvTimeoutError::Disconnected) {
            session.stopped.store(true, Ordering::Release);
            "native_test_worker_stopped".to_string()
        } else {
            "native_test_timeout".to_string()
        }
    })?
}

#[cfg(feature = "native-test")]
fn selector(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    element_id: String,
) -> Result<&'static str, String> {
    let mut names = session
        .selector_names
        .lock()
        .map_err(|_| "native_test_lock_failed".to_string())?;
    Ok(*names
        .entry(element_id.clone())
        .or_insert_with(|| Box::leak(element_id.into_boxed_str())))
}

#[cfg(feature = "native-test")]
fn initialize(width: f32, height: f32) -> TestSession {
    use gpui::IntoElement as _;

    let mut app = gpui::TestAppContext::single();
    app.update(gpui_component::init);
    let runtime = Arc::new(crate::runtime::RuntimeState::new());
    let state = Arc::new(crate::WindowState::new(
        ElementNode::empty_root(),
        Vec::new(),
    ));
    let runtime_for_view = runtime.clone();
    let (view, context) = app.add_window_view(move |_window, _cx| {
        ElixirRoot::new(state, runtime_for_view, 1, false, false)
    });
    context.draw(
        gpui::Point::default(),
        gpui::size(gpui::px(width), gpui::px(height)),
        |_window, _cx| view.clone().into_any_element(),
    );

    TestSession {
        runtime,
        view,
        context: context.clone(),
    }
}

#[cfg(feature = "native-test")]
fn target_bounds(
    context: &mut gpui::VisualTestContext,
    element_id: &'static str,
) -> Result<gpui::Bounds<gpui::Pixels>, String> {
    context
        .debug_bounds(element_id)
        .ok_or_else(|| "unknown_native_test_target".to_string())
}

#[cfg(feature = "native-test")]
pub(crate) fn start(width: f32, height: f32) -> Result<NativeTestSessionResource, String> {
    let (commands, receiver) = std::sync::mpsc::sync_channel(MAX_PENDING_COMMANDS);
    let (ready, readiness) = std::sync::mpsc::sync_channel(1);

    std::thread::Builder::new()
        .name("gpui-native-test".to_string())
        .spawn(move || {
            let ready_after_panic = ready.clone();
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                let session = initialize(width, height);
                let _ = ready.send(Ok(()));
                run_initialized(session, receiver);
            }));
            if result.is_err() {
                let _ = ready_after_panic.send(Err("native_test_worker_stopped".to_string()));
            }
        })
        .map_err(|_| "native_test_worker_start_failed".to_string())?;

    readiness
        .recv_timeout(COMMAND_TIMEOUT)
        .map_err(|_| "native_test_worker_start_failed".to_string())??;

    Ok(NativeTestSessionResource {
        commands,
        stopped: AtomicBool::new(false),
        selector_names: std::sync::Mutex::new(std::collections::HashMap::new()),
    })
}

#[cfg(feature = "native-test")]
fn run_initialized(mut session: TestSession, receiver: std::sync::mpsc::Receiver<TestCommand>) {
    while let Ok(command) = receiver.recv() {
        if handle_command(&mut session, command) {
            break;
        }
    }
}

#[cfg(feature = "native-test")]
fn handle_command(session: &mut TestSession, command: TestCommand) -> bool {
    match command {
        TestCommand::Stop { reply } => {
            if let Some(reply) = reply {
                let _ = reply.send(Ok(()));
            }
            true
        }
        command => {
            handle_non_stop_command(session, command);
            false
        }
    }
}

#[cfg(feature = "native-test")]
fn handle_non_stop_command(session: &mut TestSession, command: TestCommand) {
    // Reuse the same interpreter by handling every non-stop command directly.
    match command {
        TestCommand::Render { tree, reply } => {
            let view = session.view.clone();
            view.update(&mut session.context.cx, |root, cx| {
                *root.window_state.tree.lock().expect("native test tree") = *tree;
                cx.notify();
            });
            session.context.run_until_parked();
            let _ = reply.send(Ok(()));
        }
        TestCommand::Focus {
            component_id,
            reply,
        } => {
            let view = session.view.clone();
            let result = session.context.update(|window, cx| {
                let focus = view.update(cx, |root, _cx| {
                    root.runtime
                        .focus_handles
                        .lock()
                        .ok()
                        .and_then(|handles| handles.get(&(1, component_id)).cloned())
                });
                focus
                    .ok_or_else(|| "unknown_focus_target".to_string())
                    .map(|focus| focus.focus(window, cx))
            });
            let _ = reply.send(result);
        }
        TestCommand::Click { element_id, reply } => {
            let result = target_bounds(&mut session.context, &element_id).map(|bounds| {
                session
                    .context
                    .simulate_click(bounds.center(), gpui::Modifiers::default());
            });
            let _ = reply.send(result);
        }
        TestCommand::ClickAt { x, y, reply } => {
            session.context.simulate_click(
                gpui::point(gpui::px(x), gpui::px(y)),
                gpui::Modifiers::default(),
            );
            let _ = reply.send(Ok(()));
        }
        TestCommand::Scroll {
            element_id,
            delta_x,
            delta_y,
            reply,
        } => {
            let result = target_bounds(&mut session.context, &element_id).map(|bounds| {
                session.context.simulate_event(gpui::ScrollWheelEvent {
                    position: bounds.center(),
                    delta: gpui::ScrollDelta::Pixels(gpui::point(
                        gpui::px(delta_x),
                        gpui::px(delta_y),
                    )),
                    modifiers: gpui::Modifiers::default(),
                    touch_phase: gpui::TouchPhase::Moved,
                });
                session.context.run_until_parked();
            });
            let _ = reply.send(result);
        }
        TestCommand::Input { text, reply } => {
            session.context.simulate_input(&text);
            let _ = reply.send(Ok(()));
        }
        TestCommand::Resize {
            width,
            height,
            reply,
        } => {
            session
                .context
                .simulate_resize(gpui::size(gpui::px(width), gpui::px(height)));
            session.context.run_until_parked();
            let _ = reply.send(Ok(()));
        }
        TestCommand::Bounds { element_id, reply } => {
            let result =
                target_bounds(&mut session.context, &element_id).map(|bounds| TestBounds {
                    x: f32::from(bounds.origin.x) as f64,
                    y: f32::from(bounds.origin.y) as f64,
                    width: f32::from(bounds.size.width) as f64,
                    height: f32::from(bounds.size.height) as f64,
                });
            let _ = reply.send(result);
        }
        TestCommand::Idle { reply } => {
            session.context.run_until_parked();
            let _ = reply.send(Ok(()));
        }
        TestCommand::Advance {
            milliseconds,
            reply,
        } => {
            session
                .context
                .cx
                .executor()
                .advance_clock(std::time::Duration::from_millis(milliseconds));
            session.context.run_until_parked();
            let _ = reply.send(Ok(()));
        }
        TestCommand::Key { key, reply } => {
            session.context.simulate_keystrokes(&key);
            let _ = reply.send(Ok(()));
        }
        TestCommand::Events { reply } => {
            let result = session
                .runtime
                .events
                .lock()
                .map_err(|_| "native_test_lock_failed".to_string())
                .map(|mut events| std::mem::take(&mut *events));
            let _ = reply.send(result);
        }
        TestCommand::Stop { .. } => unreachable!(),
    }
}

#[cfg(feature = "native-test")]
pub(crate) fn render(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    tree: ElementNode,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Render {
        tree: Box::new(tree),
        reply,
    })
}
#[cfg(feature = "native-test")]
pub(crate) fn focus(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    component_id: String,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Focus {
        component_id,
        reply,
    })
}
#[cfg(feature = "native-test")]
pub(crate) fn click(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    element_id: String,
) -> Result<(), String> {
    let element_id = selector(session, element_id)?;
    execute(session, |reply| TestCommand::Click { element_id, reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn click_at(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    x: f32,
    y: f32,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::ClickAt { x, y, reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn scroll(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    element_id: String,
    delta_x: f32,
    delta_y: f32,
) -> Result<(), String> {
    let element_id = selector(session, element_id)?;
    execute(session, |reply| TestCommand::Scroll {
        element_id,
        delta_x,
        delta_y,
        reply,
    })
}
#[cfg(feature = "native-test")]
pub(crate) fn input(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    text: String,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Input { text, reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn resize(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    width: f32,
    height: f32,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Resize {
        width,
        height,
        reply,
    })
}
#[cfg(feature = "native-test")]
pub(crate) fn bounds(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    element_id: String,
) -> Result<TestBounds, String> {
    let element_id = selector(session, element_id)?;
    execute(session, |reply| TestCommand::Bounds { element_id, reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn idle(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Idle { reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn advance(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    milliseconds: u64,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Advance {
        milliseconds,
        reply,
    })
}
#[cfg(feature = "native-test")]
pub(crate) fn key(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
    key: String,
) -> Result<(), String> {
    execute(session, |reply| TestCommand::Key { key, reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn events(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
) -> Result<Vec<NativeEvent>, String> {
    execute(session, |reply| TestCommand::Events { reply })
}
#[cfg(feature = "native-test")]
pub(crate) fn stop(
    session: &rustler::ResourceArc<NativeTestSessionResource>,
) -> Result<(), String> {
    if session.stopped.swap(true, Ordering::AcqRel) {
        return Ok(());
    }
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    session
        .commands
        .try_send(TestCommand::Stop { reply: Some(reply) })
        .map_err(|_| "native_test_worker_stopped".to_string())?;
    receiver
        .recv_timeout(COMMAND_TIMEOUT)
        .map_err(|_| "native_test_worker_stopped".to_string())?
}
