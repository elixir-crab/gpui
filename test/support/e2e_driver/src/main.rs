use std::{env, error::Error, io};
use x11rb::{
    connection::Connection,
    protocol::xproto::{ClientMessageEvent, ConnectionExt, EventMask},
    CURRENT_TIME,
};

fn main() -> Result<(), Box<dyn Error>> {
    let mut args = env::args().skip(1);

    match (args.next().as_deref(), args.next(), args.next()) {
        (Some("close-window"), Some(window), None) => close_window(window.parse()?),
        _ => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: gpui-e2e-driver close-window WINDOW_ID",
        )
        .into()),
    }
}

fn close_window(window: u32) -> Result<(), Box<dyn Error>> {
    let (connection, _screen) = x11rb::connect(None)?;
    let wm_protocols = connection
        .intern_atom(false, b"WM_PROTOCOLS")?
        .reply()?
        .atom;
    let wm_delete_window = connection
        .intern_atom(false, b"WM_DELETE_WINDOW")?
        .reply()?
        .atom;
    let event = ClientMessageEvent::new(
        32,
        window,
        wm_protocols,
        [wm_delete_window, CURRENT_TIME, 0, 0, 0],
    );

    connection
        .send_event(false, window, EventMask::NO_EVENT, event)?
        .check()?;
    connection.flush()?;
    Ok(())
}
