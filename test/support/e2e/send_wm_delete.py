#!/usr/bin/env python3
"""Send the ICCCM WM_DELETE_WINDOW client message without requiring a window manager."""

import sys

from Xlib import X, display, protocol


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: send_wm_delete.py WINDOW_ID")

    connection = display.Display()
    window = connection.create_resource_object("window", int(sys.argv[1]))
    wm_protocols = connection.intern_atom("WM_PROTOCOLS")
    wm_delete_window = connection.intern_atom("WM_DELETE_WINDOW")
    event = protocol.event.ClientMessage(
        window=window,
        client_type=wm_protocols,
        data=(32, [wm_delete_window, X.CurrentTime, 0, 0, 0]),
    )
    window.send_event(event, event_mask=X.NoEventMask)
    connection.flush()


if __name__ == "__main__":
    main()
