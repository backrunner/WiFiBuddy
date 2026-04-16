#!/usr/bin/env swift

import AppKit
import CoreGraphics

// Renders the WiFiBuddy Liquid Glass icon following macOS 26 HIG: a bold
// gradient background, a thick stacked-glass center puck with specular +
// refraction highlights, and a vivid Wi-Fi mark sitting on top. The script
// outputs a final .icns at <output-icns-path>; all intermediate iconset +
// preview PNGs land in <scratch-dir>.
//
// Usage: generate_icon.swift <output-icns-path> [<scratch-dir>]

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("generate_icon.swift: missing output path\n".utf8))
    exit(64)
}
let outputIcnsPath = CommandLine.arguments[1]
let scratchDir: String
if CommandLine.arguments.count >= 3 {
    scratchDir = CommandLine.arguments[2]
} else {
    scratchDir = NSTemporaryDirectory().appending("wifibuddy-icon")
}
let size = 1024

func makeRep(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    )!
    rep.size = NSSize(width: size, height: size)
    return rep
}

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func drawIcon(size: CGFloat, into ctx: CGContext) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius: CGFloat = size * 0.2226
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // -----------------------------------------------------------------------
    // 1. Background — diagonal gradient with a secondary radial "bloom"
    // -----------------------------------------------------------------------
    let bgPath = CGPath(
        roundedRect: rect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Primary diagonal: clean sky → azure → deep ocean blue (no violet)
    let bgColors = [
        color(0.30, 0.72, 1.00),
        color(0.08, 0.47, 0.97),
        color(0.02, 0.22, 0.62)
    ] as CFArray
    let bgGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: bgColors,
        locations: [0.0, 0.55, 1.0]
    )!
    ctx.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: size * 0.05, y: size * 0.95),
        end: CGPoint(x: size * 0.95, y: size * 0.05),
        options: []
    )

    // Radial bloom in the upper-left for depth
    let bloomColors = [
        color(1.0, 1.0, 1.0, 0.20),
        color(1.0, 1.0, 1.0, 0.0)
    ] as CFArray
    let bloomGradient = CGGradient(colorsSpace: colorSpace, colors: bloomColors, locations: [0, 1])!
    ctx.drawRadialGradient(
        bloomGradient,
        startCenter: CGPoint(x: size * 0.26, y: size * 0.82),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.26, y: size * 0.82),
        endRadius: size * 0.55,
        options: []
    )

    // Deep corner shade for bottom-right grounding (pure blue, no magenta)
    let shadeColors = [
        color(0.0, 0.0, 0.0, 0.0),
        color(0.0, 0.08, 0.20, 0.24)
    ] as CFArray
    let shadeGradient = CGGradient(colorsSpace: colorSpace, colors: shadeColors, locations: [0, 1])!
    ctx.drawLinearGradient(
        shadeGradient,
        start: CGPoint(x: size * 0.5, y: size * 0.5),
        end: CGPoint(x: size, y: 0),
        options: []
    )
    ctx.restoreGState()

    // -----------------------------------------------------------------------
    // 2. Outer glass ring — big translucent disc with crisp rim
    // -----------------------------------------------------------------------
    let outerInset: CGFloat = size * 0.14
    let outerRect = rect.insetBy(dx: outerInset, dy: outerInset)
    let outerPath = CGPath(ellipseIn: outerRect, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.025),
        blur: size * 0.06,
        color: color(0, 0.05, 0.20, 0.42)
    )
    ctx.addPath(outerPath)
    ctx.setFillColor(color(1, 1, 1, 0.12))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.clip()
    let outerGlassColors = [
        color(1, 1, 1, 0.42),
        color(1, 1, 1, 0.10),
        color(1, 1, 1, 0.02)
    ] as CFArray
    let outerGlassGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: outerGlassColors,
        locations: [0.0, 0.55, 1.0]
    )!
    ctx.drawLinearGradient(
        outerGlassGradient,
        start: CGPoint(x: outerRect.minX, y: outerRect.maxY),
        end: CGPoint(x: outerRect.maxX, y: outerRect.minY),
        options: []
    )

    // Top specular arc (crescent-ish) for refraction feel
    let crescentRect = CGRect(
        x: outerRect.minX + outerRect.width * 0.08,
        y: outerRect.maxY - outerRect.height * 0.32,
        width: outerRect.width * 0.84,
        height: outerRect.height * 0.22
    )
    let crescentColors = [
        color(1, 1, 1, 0.8),
        color(1, 1, 1, 0.0)
    ] as CFArray
    let crescentGradient = CGGradient(colorsSpace: colorSpace, colors: crescentColors, locations: [0, 1])!
    ctx.drawRadialGradient(
        crescentGradient,
        startCenter: CGPoint(x: crescentRect.midX, y: crescentRect.maxY),
        startRadius: 0,
        endCenter: CGPoint(x: crescentRect.midX, y: crescentRect.midY),
        endRadius: crescentRect.width * 0.55,
        options: []
    )
    ctx.restoreGState()

    // Hairline rim
    ctx.addPath(outerPath)
    ctx.setStrokeColor(color(1, 1, 1, 0.55))
    ctx.setLineWidth(size * 0.0055)
    ctx.strokePath()

    // Inner shadow (bottom half) to suggest glass thickness
    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.clip()
    let innerShadowColors = [
        color(0, 0.05, 0.22, 0.28),
        color(0, 0, 0, 0.0)
    ] as CFArray
    let innerShadow = CGGradient(colorsSpace: colorSpace, colors: innerShadowColors, locations: [0, 1])!
    ctx.drawLinearGradient(
        innerShadow,
        start: CGPoint(x: outerRect.midX, y: outerRect.minY),
        end: CGPoint(x: outerRect.midX, y: outerRect.midY),
        options: []
    )
    ctx.restoreGState()

    // -----------------------------------------------------------------------
    // 3. Inner glass disc — smaller, brighter core
    // -----------------------------------------------------------------------
    let innerInset: CGFloat = size * 0.27
    let innerRect = rect.insetBy(dx: innerInset, dy: innerInset)
    let innerPath = CGPath(ellipseIn: innerRect, transform: nil)

    ctx.saveGState()
    ctx.addPath(innerPath)
    ctx.clip()
    let coreColors = [
        color(1, 1, 1, 0.58),
        color(0.66, 0.86, 1.0, 0.20),
        color(0.18, 0.48, 0.92, 0.0)
    ] as CFArray
    let coreGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: coreColors,
        locations: [0.0, 0.6, 1.0]
    )!
    ctx.drawRadialGradient(
        coreGradient,
        startCenter: CGPoint(x: innerRect.midX - innerRect.width * 0.18,
                             y: innerRect.midY + innerRect.height * 0.22),
        startRadius: 0,
        endCenter: CGPoint(x: innerRect.midX, y: innerRect.midY),
        endRadius: innerRect.width * 0.7,
        options: [.drawsAfterEndLocation]
    )
    ctx.restoreGState()

    // Inner rim
    ctx.addPath(innerPath)
    ctx.setStrokeColor(color(1, 1, 1, 0.4))
    ctx.setLineWidth(size * 0.004)
    ctx.strokePath()

    // -----------------------------------------------------------------------
    // 4. Wi-Fi mark — three precise arcs and a dot
    // -----------------------------------------------------------------------
    // The arcs sit entirely above the dot, so to visually center the mark we
    // place the dot a touch below the icon centerline — the resulting bounding
    // box (dot bottom → arc top) is then balanced around Y = size * 0.5.
    let arcSpecs: [(radius: CGFloat, lineWidth: CGFloat, alpha: CGFloat)] = [
        (size * 0.095, size * 0.038, 1.00),
        (size * 0.170, size * 0.034, 0.92),
        (size * 0.245, size * 0.030, 0.82)
    ]
    let dotDiameter = size * 0.062
    // Dot is a half-circle below its center, so the shape's vertical span is
    // [center - dotRadius, center + maxArcRadius]. Balancing → dotCenter_y =
    // iconCenter - (maxArcRadius - dotRadius) / 2
    let maxArcRadius = arcSpecs.last!.radius
    let dotRadius = dotDiameter / 2
    let wifiCenterY = size * 0.5 - (maxArcRadius - dotRadius) / 2
    let wifiCenter = CGPoint(x: size * 0.5, y: wifiCenterY)

    ctx.setLineCap(.round)
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.006),
        blur: size * 0.015,
        color: color(0, 0.05, 0.22, 0.35)
    )
    for spec in arcSpecs {
        ctx.setStrokeColor(color(1, 1, 1, spec.alpha))
        ctx.setLineWidth(spec.lineWidth)
        let path = CGMutablePath()
        path.addArc(
            center: wifiCenter,
            radius: spec.radius,
            startAngle: .pi * 0.22,
            endAngle: .pi * 0.78,
            clockwise: false
        )
        ctx.addPath(path)
        ctx.strokePath()
    }
    ctx.restoreGState()

    // Wi-Fi dot with subtle glow
    let dotRect = CGRect(
        x: wifiCenter.x - dotRadius,
        y: wifiCenter.y - dotRadius,
        width: dotDiameter,
        height: dotDiameter
    )

    ctx.saveGState()
    ctx.setShadow(
        offset: .zero,
        blur: size * 0.02,
        color: color(0.25, 0.62, 1.0, 0.75)
    )
    ctx.setFillColor(color(1, 1, 1, 1))
    ctx.fillEllipse(in: dotRect)
    ctx.restoreGState()
}

func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = makeRep(size: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    drawIcon(size: CGFloat(size), into: ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Generate iconset directory inside the scratch area
try? FileManager.default.createDirectory(atPath: scratchDir, withIntermediateDirectories: true)
let iconsetPath = (scratchDir as NSString).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let iconSizes: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, name) in iconSizes {
    let rep = renderIcon(size: px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    let url = URL(fileURLWithPath: iconsetPath).appendingPathComponent(name)
    try! data.write(to: url)
}

let preview = renderIcon(size: size)
let previewData = preview.representation(using: .png, properties: [:])!
try! previewData.write(to: URL(fileURLWithPath: (scratchDir as NSString).appendingPathComponent("AppIcon.png")))

let outputDirPath = (outputIcnsPath as NSString).deletingLastPathComponent
try? FileManager.default.createDirectory(atPath: outputDirPath, withIntermediateDirectories: true)
let process = Process()
process.launchPath = "/usr/bin/iconutil"
process.arguments = ["-c", "icns", iconsetPath, "-o", outputIcnsPath]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Wrote \(outputIcnsPath)")
} else {
    print("iconutil failed with status \(process.terminationStatus)")
    exit(process.terminationStatus)
}
