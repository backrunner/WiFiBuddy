#!/usr/bin/env swift
// Usage: crop_png.swift <input.png> <output.png> <x> <y> <w> <h>
// Coordinates are in pixels, origin top-left.

import AppKit
import CoreGraphics

guard CommandLine.arguments.count == 7 else {
    FileHandle.standardError.write(Data("usage: crop_png.swift <in> <out> <x> <y> <w> <h>\n".utf8))
    exit(64)
}
let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let x = Int(CommandLine.arguments[3])!
let y = Int(CommandLine.arguments[4])!
let w = Int(CommandLine.arguments[5])!
let h = Int(CommandLine.arguments[6])!

guard let data = NSData(contentsOfFile: input),
      let src = CGImageSourceCreateWithData(data, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write(Data("failed to load \(input)\n".utf8))
    exit(1)
}

// PNG / CGImage coordinate space is top-left origin, so we pass (x, y, w, h)
// through without flipping.
let rect = CGRect(x: x, y: y, width: w, height: h)
guard let cropped = image.cropping(to: rect) else {
    FileHandle.standardError.write(Data("crop failed\n".utf8))
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: cropped)
guard let outData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("png encode failed\n".utf8))
    exit(1)
}
try outData.write(to: URL(fileURLWithPath: output))
print("Wrote \(output) (\(w)x\(h))")
