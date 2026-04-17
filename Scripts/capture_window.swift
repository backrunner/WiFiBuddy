#!/usr/bin/env swift

import AppKit
import CoreGraphics

// Usage: capture_window.swift <bundle-id-or-process-name> <output-path> [window-title-substring]
//
// Locates the *owner* app by bundle ID or process name and captures a specific
// on-screen window directly via `screencapture -l <windowID>` — no AppleScript
// permission required. If a window title substring is provided, only windows
// whose title contains it are eligible (useful to pick "Settings" vs main).

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: capture_window.swift <app> <out.png> [title]\n".utf8))
    exit(64)
}
let appIdentifier = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let titleFilter = CommandLine.arguments.count >= 4 ? CommandLine.arguments[3] : nil

let running = NSWorkspace.shared.runningApplications.first { app in
    (app.bundleIdentifier == appIdentifier)
        || (app.localizedName == appIdentifier)
        || (app.executableURL?.lastPathComponent == appIdentifier)
}

guard let app = running else {
    FileHandle.standardError.write(Data("no running app matching \(appIdentifier)\n".utf8))
    exit(1)
}

let pid = app.processIdentifier
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write(Data("CGWindowListCopyWindowInfo returned nil\n".utf8))
    exit(1)
}

let candidates = windowList
    .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    .filter { window in
        // Ignore tiny shadow/overlay windows
        if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
           let w = bounds["Width"], let h = bounds["Height"], w >= 200, h >= 200 {
            return true
        }
        return false
    }
    .filter { window in
        guard let filter = titleFilter else { return true }
        let title = (window[kCGWindowName as String] as? String) ?? ""
        return title.lowercased().contains(filter.lowercased())
    }

guard let target = candidates.first,
      let windowNumber = target[kCGWindowNumber as String] as? Int else {
    FileHandle.standardError.write(Data("no matching window for pid \(pid)\n".utf8))
    exit(1)
}

let process = Process()
process.launchPath = "/usr/sbin/screencapture"
// -o: no window shadow in output; -l <id>: capture a specific window; -x: silent
process.arguments = ["-o", "-x", "-l", "\(windowNumber)", outputPath]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Captured window \(windowNumber) to \(outputPath)")
} else {
    FileHandle.standardError.write(Data("screencapture failed: \(process.terminationStatus)\n".utf8))
    exit(process.terminationStatus)
}
