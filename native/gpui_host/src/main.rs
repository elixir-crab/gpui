use eetf::{Atom, Binary, Map, Term};
use std::collections::HashMap;
use std::io::{self, Read, Write};

#[cfg(feature = "real-gpui")]
use std::sync::atomic::{AtomicBool, Ordering};

#[cfg(feature = "real-gpui")]
static GPUI_STARTED: AtomicBool = AtomicBool::new(false);

include!("generated_commands.rs");

fn main() -> io::Result<()> {
    let mut input = io::stdin().lock();
    let mut output = io::stdout().lock();

    while let Some(payload) = read_packet(&mut input)? {
        let reply = match Term::decode(&payload[..]) {
            Ok(term) => handle(term),
            Err(error) => error_reply(format!("decode_failed: {error}")),
        };

        write_term_packet(&mut output, &reply)?;
    }

    Ok(())
}

fn read_packet(reader: &mut impl Read) -> io::Result<Option<Vec<u8>>> {
    let mut length = [0_u8; 4];

    match reader.read_exact(&mut length) {
        Ok(()) => {}
        Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(error) => return Err(error),
    }

    let length = u32::from_be_bytes(length) as usize;
    let mut payload = vec![0_u8; length];
    reader.read_exact(&mut payload)?;
    Ok(Some(payload))
}

fn write_term_packet(writer: &mut impl Write, term: &Term) -> io::Result<()> {
    let mut payload = Vec::new();
    term.encode(&mut payload)
        .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error.to_string()))?;

    writer.write_all(&(payload.len() as u32).to_be_bytes())?;
    writer.write_all(&payload)?;
    writer.flush()
}

fn handle(term: Term) -> Term {
    let op = match map_get_atom(&term, "op") {
        Some(op) => op,
        None => return error_reply("missing_op"),
    };

    let nil_payload = map([]);
    let payload = map_get(&term, "payload").unwrap_or(&nil_payload);
    dispatch_host_command(&op, payload)
}

fn handle_ping() -> Term {
    ok_reply(map([(atom("pong"), atom("ok"))]))
}

#[cfg(not(feature = "real-gpui"))]
fn handle_open_window(command: OpenWindowCommand) -> Term {
    let _ = (command.title, command.size, command.root);

    ok_reply(map([
        (atom("event"), atom("window_open_requested")),
        (atom("backend"), atom("stub")),
    ]))
}

#[cfg(feature = "real-gpui")]
fn handle_open_window(command: OpenWindowCommand) -> Term {
    let title = term_to_string(command.title).unwrap_or_else(|| "GPUI + Elixir".to_string());

    if GPUI_STARTED.swap(true, Ordering::SeqCst) {
        return error_reply("gpui_already_started");
    }

    std::thread::spawn(move || run_gpui_window(title));

    ok_reply(map([
        (atom("event"), atom("window_open_requested")),
        (atom("backend"), atom("gpui")),
    ]))
}

#[cfg(feature = "real-gpui")]
fn run_gpui_window(title: String) {
    use gpui::{div, px, rgb, size, App, Bounds, Context, Render, Window, WindowBounds, WindowOptions};
    use gpui::prelude::*;

    struct HelloWorld {
        title: String,
    }

    impl Render for HelloWorld {
        fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl gpui::IntoElement {
            div()
                .flex()
                .flex_col()
                .gap_3()
                .bg(rgb(0x505050))
                .size(px(500.0))
                .justify_center()
                .items_center()
                .text_xl()
                .text_color(rgb(0xffffff))
                .child(format!("Hello from Elixir/OTP via {}", self.title))
        }
    }

    gpui_platform::application().run(move |cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(500.0), px(500.0)), cx);
        let _ = cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |window, cx| {
                window.set_window_title(&title);
                cx.new(|_| HelloWorld { title: title.clone() })
            },
        );
        cx.activate(true);
    });
}

fn handle_close_window(command: CloseWindowCommand) -> Term {
    let _ = command.window_id;
    ok_reply(map([(atom("event"), atom("window_close_requested"))]))
}

fn handle_update_view(command: UpdateViewCommand) -> Term {
    let _ = (command.view_id, command.tree);
    ok_reply(map([(atom("event"), atom("view_update_requested"))]))
}

fn handle_shutdown() -> Term {
    ok_reply(map([(atom("event"), atom("shutdown_requested"))]))
}

fn map_get_atom(term: &Term, key: &str) -> Option<String> {
    let value = map_get(term, key)?;

    match value {
        Term::Atom(atom) => Some(atom.name.clone()),
        _ => None,
    }
}

fn map_get<'a>(term: &'a Term, key: &str) -> Option<&'a Term> {
    let Term::Map(map) = term else {
        return None;
    };

    map.map.get(&atom(key))
}

fn required_payload<'a>(payload: &'a Term, key: &str) -> Result<&'a Term, String> {
    map_get(payload, key).ok_or_else(|| format!("missing_payload_field:{key}"))
}

#[cfg(feature = "real-gpui")]
fn term_to_string(term: &Term) -> Option<String> {
    match term {
        Term::Binary(binary) => String::from_utf8(binary.bytes.clone()).ok(),
        Term::ByteList(bytes) => String::from_utf8(bytes.bytes.clone()).ok(),
        Term::Atom(atom) => Some(atom.name.clone()),
        _ => None,
    }
}

fn ok_reply(payload: Term) -> Term {
    map([
        (atom("op"), atom("reply")),
        (atom("status"), atom("ok")),
        (atom("payload"), payload),
    ])
}

fn error_reply(reason: impl Into<String>) -> Term {
    map([
        (atom("op"), atom("reply")),
        (atom("status"), atom("error")),
        (atom("reason"), binary(reason.into())),
    ])
}

fn atom(name: &str) -> Term {
    Term::from(Atom::from(name))
}

fn binary(value: String) -> Term {
    Term::from(Binary { bytes: value.into_bytes() })
}

fn map<const N: usize>(entries: [(Term, Term); N]) -> Term {
    Term::from(Map {
        map: HashMap::from(entries),
    })
}
