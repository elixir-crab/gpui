use std::{env, error::Error, fs::File, io, io::Write};
use x11rb::{
    connection::Connection,
    protocol::xproto::{ClientMessageEvent, ConnectionExt, EventMask, ImageFormat},
    CURRENT_TIME,
};

fn main() -> Result<(), Box<dyn Error>> {
    let args = env::args().skip(1).collect::<Vec<_>>();

    match args.as_slice() {
        [command, window] if command == "close-window" => close_window(window.parse()?),
        [command, window, path] if command == "capture-window" => {
            capture_window(window.parse()?, path)
        }
        _ => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: gpui-e2e-driver close-window WINDOW_ID | capture-window WINDOW_ID PATH",
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

fn capture_window(window: u32, path: &str) -> Result<(), Box<dyn Error>> {
    let (connection, _screen) = x11rb::connect(None)?;
    let geometry = connection.get_geometry(window)?.reply()?;
    let image = connection
        .get_image(
            ImageFormat::Z_PIXMAP,
            window,
            0,
            0,
            geometry.width,
            geometry.height,
            u32::MAX,
        )?
        .reply()?;

    let width = usize::from(geometry.width);
    let height = usize::from(geometry.height);
    let row_size = (width * 3 + 3) & !3;
    let image_size = row_size * height;
    let file_size = 54 + image_size;
    let mut header = Vec::with_capacity(54);
    header.extend_from_slice(b"BM");
    header.extend_from_slice(&(file_size as u32).to_le_bytes());
    header.extend_from_slice(&[0; 4]);
    header.extend_from_slice(&54_u32.to_le_bytes());
    header.extend_from_slice(&40_u32.to_le_bytes());
    header.extend_from_slice(&(width as i32).to_le_bytes());
    header.extend_from_slice(&(height as i32).to_le_bytes());
    header.extend_from_slice(&1_u16.to_le_bytes());
    header.extend_from_slice(&24_u16.to_le_bytes());
    header.extend_from_slice(&0_u32.to_le_bytes());
    header.extend_from_slice(&(image_size as u32).to_le_bytes());
    header.extend_from_slice(&2835_i32.to_le_bytes());
    header.extend_from_slice(&2835_i32.to_le_bytes());
    header.extend_from_slice(&[0; 8]);

    let mut file = File::create(path)?;
    file.write_all(&header)?;
    let padding = vec![0; row_size - width * 3];
    for row in (0..height).rev() {
        let start = row * width * 4;
        for pixel in image.data[start..start + width * 4].chunks_exact(4) {
            file.write_all(&pixel[..3])?;
        }
        file.write_all(&padding)?;
    }
    Ok(())
}
