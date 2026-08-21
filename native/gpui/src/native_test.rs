#[cfg(feature = "native-test")]
use crate::*;

#[cfg(feature = "native-test")]
use std::sync::{Arc, Mutex, OnceLock};

#[cfg(feature = "native-test")]
type TestCommandReply<T> = std::sync::mpsc::SyncSender<Result<T, String>>;

#[cfg(feature = "native-test")]
enum TestCommand {
    Start {
        width: f32,
        height: f32,
        reply: TestCommandReply<u64>,
    },
    Render {
        id: u64,
        tree: Box<ElementNode>,
        reply: TestCommandReply<()>,
    },
    Focus {
        id: u64,
        component_id: String,
        reply: TestCommandReply<()>,
    },
    Key {
        id: u64,
        key: String,
        reply: TestCommandReply<()>,
    },
    Events {
        id: u64,
        reply: TestCommandReply<Vec<NativeEvent>>,
    },
    Stop {
        id: u64,
        reply: TestCommandReply<()>,
    },
}

#[cfg(feature = "native-test")]
struct TestSession {
    runtime: SharedRuntime,
    view: gpui::Entity<ElixirRoot>,
    context: gpui::VisualTestContext,
}

#[cfg(feature = "native-test")]
static TEST_COMMANDS: OnceLock<Mutex<std::sync::mpsc::Sender<TestCommand>>> = OnceLock::new();

#[cfg(feature = "native-test")]
fn command_sender() -> Result<std::sync::mpsc::Sender<TestCommand>, String> {
    let sender = TEST_COMMANDS.get_or_init(|| {
        let (sender, receiver) = std::sync::mpsc::channel();
        std::thread::Builder::new()
            .name("gpui-native-test".to_string())
            .spawn(move || run(receiver))
            .expect("native test thread must start");
        Mutex::new(sender)
    });
    sender
        .lock()
        .map_err(|_| "native_test_lock_failed".to_string())
        .map(|sender| sender.clone())
}

#[cfg(feature = "native-test")]
fn execute<T>(build: impl FnOnce(TestCommandReply<T>) -> TestCommand) -> Result<T, String> {
    let (reply, receiver) = std::sync::mpsc::sync_channel(1);
    command_sender()?
        .send(build(reply))
        .map_err(|_| "native_test_stopped".to_string())?;
    receiver
        .recv_timeout(std::time::Duration::from_secs(5))
        .map_err(|_| "native_test_timeout".to_string())?
}

#[cfg(feature = "native-test")]
fn run(receiver: std::sync::mpsc::Receiver<TestCommand>) {
    use gpui::IntoElement as _;
    use std::collections::HashMap;

    let mut app = gpui::TestAppContext::single();
    app.update(gpui_component::init);
    let mut sessions = HashMap::<u64, TestSession>::new();
    let mut next_id = 1_u64;

    while let Ok(command) = receiver.recv() {
        match command {
            TestCommand::Start {
                width,
                height,
                reply,
            } => {
                let id = next_id;
                next_id = next_id.saturating_add(1);
                let runtime = Arc::new(crate::runtime::RuntimeState::new());
                let state = Arc::new(crate::WindowState::new(
                    ElementNode::empty_root(),
                    Vec::new(),
                ));
                let runtime_for_view = runtime.clone();
                let state_for_view = state;
                let (view, context) = app.add_window_view(move |_window, _cx| {
                    ElixirRoot::new(state_for_view, runtime_for_view, id, false, false)
                });
                context.draw(
                    gpui::Point::default(),
                    gpui::size(gpui::px(width), gpui::px(height)),
                    |_window, _cx| view.clone().into_any_element(),
                );
                sessions.insert(
                    id,
                    TestSession {
                        runtime,
                        view,
                        context: context.clone(),
                    },
                );
                let _ = reply.send(Ok(id));
            }
            TestCommand::Render { id, tree, reply } => {
                let result = sessions
                    .get_mut(&id)
                    .ok_or_else(|| "unknown_native_test".to_string())
                    .map(|session| {
                        let view = session.view.clone();
                        view.update(&mut session.context.cx, |root, cx| {
                            *root.window_state.tree.lock().expect("native test tree") = *tree;
                            cx.notify();
                        });
                        session.context.run_until_parked();
                    });
                let _ = reply.send(result);
            }
            TestCommand::Focus {
                id,
                component_id,
                reply,
            } => {
                let result = sessions
                    .get_mut(&id)
                    .ok_or_else(|| "unknown_native_test".to_string())
                    .and_then(|session| {
                        let view = session.view.clone();
                        session.context.update(|window, cx| {
                            let focus = view.update(cx, |root, _cx| {
                                root.runtime.focus_handles.lock().ok().and_then(|handles| {
                                    handles.get(&(id, component_id.clone())).cloned()
                                })
                            });
                            focus
                                .ok_or_else(|| "unknown_focus_target".to_string())
                                .map(|focus| focus.focus(window, cx))
                        })
                    });
                let _ = reply.send(result);
            }
            TestCommand::Key { id, key, reply } => {
                let result = sessions
                    .get_mut(&id)
                    .ok_or_else(|| "unknown_native_test".to_string())
                    .map(|session| session.context.simulate_keystrokes(&key));
                let _ = reply.send(result);
            }
            TestCommand::Events { id, reply } => {
                let result = sessions
                    .get(&id)
                    .ok_or_else(|| "unknown_native_test".to_string())
                    .and_then(|session| {
                        session
                            .runtime
                            .events
                            .lock()
                            .map_err(|_| "native_test_lock_failed".to_string())
                            .map(|mut events| std::mem::take(&mut *events))
                    });
                let _ = reply.send(result);
            }
            TestCommand::Stop { id, reply } => {
                sessions.remove(&id);
                let _ = reply.send(Ok(()));
            }
        }
    }
}

#[cfg(feature = "native-test")]
pub(crate) fn start(width: f32, height: f32) -> Result<u64, String> {
    execute(|reply| TestCommand::Start {
        width,
        height,
        reply,
    })
}

#[cfg(feature = "native-test")]
pub(crate) fn render(id: u64, tree: ElementNode) -> Result<(), String> {
    execute(|reply| TestCommand::Render {
        id,
        tree: Box::new(tree),
        reply,
    })
}

#[cfg(feature = "native-test")]
pub(crate) fn focus(id: u64, component_id: String) -> Result<(), String> {
    execute(|reply| TestCommand::Focus {
        id,
        component_id,
        reply,
    })
}

#[cfg(feature = "native-test")]
pub(crate) fn key(id: u64, key: String) -> Result<(), String> {
    execute(|reply| TestCommand::Key { id, key, reply })
}

#[cfg(feature = "native-test")]
pub(crate) fn events(id: u64) -> Result<Vec<NativeEvent>, String> {
    execute(|reply| TestCommand::Events { id, reply })
}

#[cfg(feature = "native-test")]
pub(crate) fn stop(id: u64) -> Result<(), String> {
    execute(|reply| TestCommand::Stop { id, reply })
}
