use crate::event::NativeEvent;
use std::sync::Mutex;

#[cfg(feature = "real-gpui")]
use crate::{RasterData, WindowCommand};
#[cfg(feature = "real-gpui")]
use futures::channel::mpsc;
#[cfg(feature = "real-gpui")]
use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicU64, Ordering},
        OnceLock,
    },
};

#[cfg(feature = "real-gpui")]
static NEXT_RUNTIME_ID: AtomicU64 = AtomicU64::new(1);
#[cfg(feature = "real-gpui")]
static GPUI_COMMANDS: OnceLock<mpsc::UnboundedSender<WindowCommand>> = OnceLock::new();

pub struct RuntimeResource {
    pub(crate) events: Mutex<Vec<NativeEvent>>,
    #[cfg(feature = "real-gpui")]
    pub(crate) id: u64,
    #[cfg(feature = "real-gpui")]
    pub(crate) resources: Mutex<HashMap<String, RasterData>>,
    #[cfg(feature = "real-gpui")]
    pub(crate) input_values: Mutex<HashMap<String, String>>,
    #[cfg(feature = "real-gpui")]
    pub(crate) command_tx: mpsc::UnboundedSender<WindowCommand>,
}

#[rustler::resource_impl]
impl rustler::Resource for RuntimeResource {}

impl RuntimeResource {
    #[cfg(feature = "real-gpui")]
    pub(crate) fn new() -> Result<Self, &'static str> {
        Ok(Self {
            events: Mutex::new(Vec::new()),
            id: NEXT_RUNTIME_ID.fetch_add(1, Ordering::Relaxed),
            resources: Mutex::new(HashMap::new()),
            input_values: Mutex::new(HashMap::new()),
            command_tx: gpui_command_sender()?,
        })
    }

    #[cfg(not(feature = "real-gpui"))]
    pub(crate) fn new() -> Self {
        Self {
            events: Mutex::new(Vec::new()),
        }
    }
}

#[cfg(feature = "real-gpui")]
fn gpui_command_sender() -> Result<mpsc::UnboundedSender<WindowCommand>, &'static str> {
    if let Some(sender) = GPUI_COMMANDS.get() {
        return Ok(sender.clone());
    }

    let (sender, receiver) = mpsc::unbounded();

    match GPUI_COMMANDS.set(sender.clone()) {
        Ok(()) => {
            std::thread::Builder::new()
                .name("gpui-application".to_string())
                .spawn(move || crate::run_gpui(receiver))
                .map_err(|_| "gpui_runtime_start_failed")?;
            Ok(sender)
        }
        Err(_sender) => GPUI_COMMANDS
            .get()
            .cloned()
            .ok_or("gpui_runtime_start_failed"),
    }
}
