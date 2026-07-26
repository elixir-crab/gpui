use crate::WindowCommand;
use futures::channel::mpsc;
use std::{
    panic::{self, AssertUnwindSafe},
    sync::mpsc as std_mpsc,
    time::Duration,
};

const STARTUP_TIMEOUT: Duration = Duration::from_secs(10);

type StartupReply = std_mpsc::SyncSender<Result<(), &'static str>>;

pub(crate) fn start(
    commands: mpsc::UnboundedReceiver<WindowCommand>,
    command_tx: mpsc::UnboundedSender<WindowCommand>,
) -> Result<(), &'static str> {
    let (ready_tx, ready_rx) = std_mpsc::sync_channel(1);
    platform::start(commands, command_tx, ready_tx)?;

    match ready_rx.recv_timeout(STARTUP_TIMEOUT) {
        Ok(result) => result,
        Err(std_mpsc::RecvTimeoutError::Timeout) => Err("gpui_host_start_timeout"),
        Err(std_mpsc::RecvTimeoutError::Disconnected) => Err("gpui_host_start_failed"),
    }
}

fn run(
    commands: mpsc::UnboundedReceiver<WindowCommand>,
    command_tx: mpsc::UnboundedSender<WindowCommand>,
    ready: StartupReply,
) {
    let _ = panic::catch_unwind(AssertUnwindSafe(|| {
        crate::run_gpui(commands, command_tx, ready)
    }));
}

#[cfg(target_os = "macos")]
mod platform {
    use super::*;
    use std::{ffi::c_void, ptr};

    struct Startup {
        commands: mpsc::UnboundedReceiver<WindowCommand>,
        command_tx: mpsc::UnboundedSender<WindowCommand>,
        ready: StartupReply,
    }

    type MainThreadEntry = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
    type StealMainThread = unsafe extern "C" fn(
        *mut std::ffi::c_char,
        *mut *mut c_void,
        MainThreadEntry,
        *mut c_void,
        *mut c_void,
    ) -> std::ffi::c_int;

    fn steal_main_thread() -> Result<StealMainThread, &'static str> {
        let symbol =
            unsafe { libc::dlsym(libc::RTLD_DEFAULT, c"erl_drv_steal_main_thread".as_ptr()) };
        if symbol.is_null() {
            return Err("gpui_main_thread_bridge_unavailable");
        }

        Ok(unsafe { std::mem::transmute::<*mut c_void, StealMainThread>(symbol) })
    }

    pub(super) fn start(
        commands: mpsc::UnboundedReceiver<WindowCommand>,
        command_tx: mpsc::UnboundedSender<WindowCommand>,
        ready: StartupReply,
    ) -> Result<(), &'static str> {
        let startup = Box::new(Startup {
            commands,
            command_tx,
            ready,
        });
        let argument = Box::into_raw(startup).cast::<c_void>();
        let mut tid = ptr::null_mut();
        let mut name = b"gpui-application\0".to_vec();

        let steal_main_thread = steal_main_thread()?;
        let result = unsafe {
            steal_main_thread(
                name.as_mut_ptr().cast(),
                &mut tid,
                main_thread_entry,
                argument,
                ptr::null_mut(),
            )
        };

        if result == 0 {
            Ok(())
        } else {
            unsafe { drop(Box::from_raw(argument.cast::<Startup>())) };
            Err("gpui_main_thread_unavailable")
        }
    }

    unsafe extern "C" fn main_thread_entry(argument: *mut c_void) -> *mut c_void {
        let startup = unsafe { Box::from_raw(argument.cast::<Startup>()) };
        super::run(startup.commands, startup.command_tx, startup.ready);
        ptr::null_mut()
    }
}

#[cfg(not(target_os = "macos"))]
mod platform {
    use super::*;

    pub(super) fn start(
        commands: mpsc::UnboundedReceiver<WindowCommand>,
        command_tx: mpsc::UnboundedSender<WindowCommand>,
        ready: StartupReply,
    ) -> Result<(), &'static str> {
        std::thread::Builder::new()
            .name("gpui-application".to_string())
            .spawn(move || super::run(commands, command_tx, ready))
            .map(|_thread| ())
            .map_err(|_error| "gpui_host_start_failed")
    }
}
