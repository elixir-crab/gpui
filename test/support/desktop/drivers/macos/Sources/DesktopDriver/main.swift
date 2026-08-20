import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ScreenCaptureKit

struct DriverError: Error, CustomStringConvertible {
    let description: String
}

struct WindowInfo {
    let id: CGWindowID
    let ownerPID: pid_t
    let bounds: CGRect
    let title: String
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func windows() throws -> [WindowInfo] {
    guard let values = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else {
        throw DriverError(description: "unable to enumerate windows")
    }

    return values.compactMap { value in
        guard
            let number = value[kCGWindowNumber as String] as? NSNumber,
            let ownerPID = value[kCGWindowOwnerPID as String] as? NSNumber,
            let boundsValue = value[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(dictionaryRepresentation: boundsValue as CFDictionary),
            let layer = value[kCGWindowLayer as String] as? NSNumber,
            layer.intValue == 0
        else { return nil }

        return WindowInfo(
            id: CGWindowID(number.uint32Value),
            ownerPID: pid_t(ownerPID.int32Value),
            bounds: bounds,
            title: value[kCGWindowName as String] as? String ?? ""
        )
    }
}

func window(id: String) throws -> WindowInfo {
    guard let parsed = UInt32(id), let match = try windows().first(where: { $0.id == parsed }) else {
        throw DriverError(description: "window not found: \(id)")
    }
    return match
}

func activate(_ info: WindowInfo) {
    NSRunningApplication(processIdentifier: info.ownerPID)?.activate(options: [.activateAllWindows])
    let app = AXUIElementCreateApplication(info.ownerPID)
    var windowsValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue) == .success,
       let axWindows = windowsValue as? [AXUIElement] {
        for axWindow in axWindows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            if (titleValue as? String) == info.title {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                break
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.08)
}

func axPoint(_ value: CFTypeRef?) -> CGPoint? {
    guard let value else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
}

func axSize(_ value: CFTypeRef?) -> CGSize? {
    guard let value else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
}

func accessibilityWindow(_ info: WindowInfo) -> AXUIElement? {
    let app = AXUIElementCreateApplication(info.ownerPID)
    var windowsValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue) == .success,
          let axWindows = windowsValue as? [AXUIElement]
    else { return nil }

    return axWindows.first { axWindow in
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
        return (titleValue as? String) == info.title
    }
}

func contentBounds(_ info: WindowInfo) -> CGRect {
    guard let axWindow = accessibilityWindow(info) else { return info.bounds }
    var childrenValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axWindow, kAXChildrenAttribute as CFString, &childrenValue) == .success,
          let children = childrenValue as? [AXUIElement]
    else { return info.bounds }

    for child in children {
        var roleValue: CFTypeRef?
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
        AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeValue)
        guard (roleValue as? String) == kAXGroupRole as String,
              let origin = axPoint(positionValue),
              let size = axSize(sizeValue),
              abs(size.width - info.bounds.width) < 1
        else { continue }
        return CGRect(origin: origin, size: size)
    }
    return info.bounds
}

func screenPoint(_ info: WindowInfo, x: String, y: String) throws -> CGPoint {
    guard let x = Double(x), let y = Double(y) else {
        throw DriverError(description: "coordinates must be numbers")
    }
    let content = contentBounds(info)
    return CGPoint(x: content.minX + x, y: content.minY + y)
}

func postMouse(_ type: CGEventType, point: CGPoint, button: CGMouseButton = .left) throws {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
        throw DriverError(description: "unable to create mouse event")
    }
    event.post(tap: .cghidEventTap)
}

func move(windowID: String, x: String, y: String) throws {
    let info = try window(id: windowID)
    activate(info)
    try postMouse(.mouseMoved, point: screenPoint(info, x: x, y: y))
}

func click(windowID: String, x: String, y: String) throws {
    let info = try window(id: windowID)
    activate(info)
    let point = try screenPoint(info, x: x, y: y)
    try postMouse(.mouseMoved, point: point)
    Thread.sleep(forTimeInterval: 0.03)
    try postMouse(.leftMouseDown, point: point)
    Thread.sleep(forTimeInterval: 0.05)
    try postMouse(.leftMouseUp, point: point)
    Thread.sleep(forTimeInterval: 0.05)
}

let keyCodes: [String: CGKeyCode] = [
    "a": 0, "c": 8, "i": 34, "v": 9,
    "tab": 48, "space": 49, "return": 36, "enter": 36,
    "escape": 53, "esc": 53, "backspace": 51, "delete": 51,
    "end": 119, "home": 115,
    "left": 123, "right": 124, "down": 125, "up": 126
]

func key(windowID: String, description: String) throws {
    let info = try window(id: windowID)
    activate(info)
    let parts = description.lowercased().split(separator: "+").map(String.init)
    guard let name = parts.last, let code = keyCodes[name] else {
        throw DriverError(description: "unsupported key: \(description)")
    }
    var flags: CGEventFlags = []
    for modifier in parts.dropLast() {
        switch modifier {
        case "super", "cmd", "command": flags.insert(.maskCommand)
        case "ctrl", "control": flags.insert(.maskControl)
        case "alt", "option": flags.insert(.maskAlternate)
        case "shift": flags.insert(.maskShift)
        default: throw DriverError(description: "unsupported modifier: \(modifier)")
        }
    }
    for down in [true, false] {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
            throw DriverError(description: "unable to create keyboard event")
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

func typeText(windowID: String, text: String) throws {
    let info = try window(id: windowID)
    activate(info)
    for character in text {
        let units = Array(String(character).utf16)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { throw DriverError(description: "unable to create text event") }
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.03)
    }
}

func close(windowID: String) throws {
    let info = try window(id: windowID)
    activate(info)
    let app = AXUIElementCreateApplication(info.ownerPID)
    var windowsValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue) == .success,
          let axWindows = windowsValue as? [AXUIElement]
    else { throw DriverError(description: "unable to query accessibility windows") }

    for axWindow in axWindows {
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
        guard (titleValue as? String) == info.title else { continue }
        var closeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXCloseButtonAttribute as CFString, &closeValue) == .success,
              let closeButton = closeValue
        else { throw DriverError(description: "window has no accessibility close button") }
        let result = AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        guard result == .success else { throw DriverError(description: "close action failed: \(result.rawValue)") }
        return
    }
    throw DriverError(description: "accessibility window not found")
}

func repeatClick(windowID: String, x: String, y: String, count: String) throws {
    guard let count = Int(count), count > 0 else {
        throw DriverError(description: "repeat count must be positive")
    }
    for _ in 0..<count { try click(windowID: windowID, x: x, y: y) }
}

func drag(windowID: String, fromX: String, fromY: String, toX: String, toY: String) throws {
    let info = try window(id: windowID)
    activate(info)
    let start = try screenPoint(info, x: fromX, y: fromY)
    let finish = try screenPoint(info, x: toX, y: toY)
    try postMouse(.mouseMoved, point: start)
    try postMouse(.leftMouseDown, point: start)
    Thread.sleep(forTimeInterval: 0.05)
    try postMouse(.leftMouseDragged, point: finish)
    Thread.sleep(forTimeInterval: 0.05)
    try postMouse(.leftMouseUp, point: finish)
}

func resize(windowID: String, width: String, height: String) throws {
    guard let width = Double(width), let height = Double(height),
          let axWindow = accessibilityWindow(try window(id: windowID))
    else { throw DriverError(description: "unable to resolve resizable window") }
    var size = CGSize(width: width, height: height)
    guard let value = AXValueCreate(.cgSize, &size) else {
        throw DriverError(description: "unable to encode window size")
    }
    let result = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, value)
    guard result == .success else {
        throw DriverError(description: "resize failed: \(result.rawValue)")
    }
}

func quartzFrame(_ screen: NSScreen) -> CGRect {
    guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
        return screen.frame
    }
    return CGDisplayBounds(id)
}

func containingScreen(_ bounds: CGRect) -> NSScreen? {
    NSScreen.screens.max { left, right in
        quartzFrame(left).intersection(bounds).width * quartzFrame(left).intersection(bounds).height <
            quartzFrame(right).intersection(bounds).width * quartzFrame(right).intersection(bounds).height
    }
}

func windowInfo(windowID: String) throws {
    let info = try window(id: windowID)
    let content = contentBounds(info)
    guard let screen = containingScreen(info.bounds),
          let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    else { throw DriverError(description: "target display not found") }
    let display = quartzFrame(screen)
    var values: [String] = []
    values.append(String(info.id))
    for value in [info.bounds.minX, info.bounds.minY, info.bounds.width, info.bounds.height] {
        values.append(String(Double(value)))
    }
    for value in [content.minX, content.minY, content.width, content.height] {
        values.append(String(Double(value)))
    }
    values.append(String(displayID))
    for value in [display.minX, display.minY, display.width, display.height] {
        values.append(String(Double(value)))
    }
    values.append(String(Double(screen.backingScaleFactor)))
    print(values.joined(separator: "\t"))
}

func capture(windowID: String, path: String) async throws {
    let info = try window(id: windowID)
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let window = content.windows.first(where: { $0.windowID == info.id }) else {
        throw DriverError(description: "capture window not found")
    }
    let display = containingScreen(info.bounds)
    let scale = display?.backingScaleFactor ?? 1
    let configuration = SCStreamConfiguration()
    configuration.width = Int(info.bounds.width * scale)
    configuration.height = Int(info.bounds.height * scale)
    configuration.showsCursor = false
    let filter = SCContentFilter(desktopIndependentWindow: window)
    let image = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
    )
    guard let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else { throw DriverError(description: "unable to create capture destination") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw DriverError(description: "unable to write capture")
    }
}

func main() async throws {
    let args = Array(CommandLine.arguments.dropFirst())
    switch args.count {
    case 2 where args[0] == "window-info": try windowInfo(windowID: args[1])
    case 2 where args[0] == "find-window":
        let title = args[1]
        let deadline = Date().addingTimeInterval(10)
        repeat {
            if let match = try windows().first(where: { $0.title == title }) {
                print(match.id)
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        } while Date() < deadline
        throw DriverError(description: "window lookup timed out: \(title)")
    case 4 where args[0] == "move": try move(windowID: args[1], x: args[2], y: args[3])
    case 4 where args[0] == "click": try click(windowID: args[1], x: args[2], y: args[3])
    case 3 where args[0] == "key": try key(windowID: args[1], description: args[2])
    case 3 where args[0] == "type": try typeText(windowID: args[1], text: args[2])
    case 6 where args[0] == "drag": try drag(windowID: args[1], fromX: args[2], fromY: args[3], toX: args[4], toY: args[5])
    case 5 where args[0] == "repeat-click": try repeatClick(windowID: args[1], x: args[2], y: args[3], count: args[4])
    case 4 where args[0] == "resize": try resize(windowID: args[1], width: args[2], height: args[3])
    case 3 where args[0] == "capture": try await capture(windowID: args[1], path: args[2])
    case 2 where args[0] == "close": try close(windowID: args[1])
    default:
        throw DriverError(description: "usage: gpui-desktop-driver find-window TITLE | move WINDOW X Y | click WINDOW X Y | key WINDOW KEY | type WINDOW TEXT | capture WINDOW PATH | close WINDOW")
    }
}

do {
    try await main()
} catch {
    fail(String(describing: error))
}
