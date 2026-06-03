#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: create_dmg_background.swift <output-png>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 900, height: 560)
let scale: CGFloat = 2
guard let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width * scale),
    pixelsHigh: Int(canvasSize.height * scale),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to allocate DMG background image.\n", stderr)
    exit(1)
}
canvas.size = canvasSize

func drawCentered(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(in: rect, withAttributes: attributes)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)

NSColor(calibratedRed: 0.966, green: 0.970, blue: 0.982, alpha: 1.0).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

let topGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.990, green: 0.992, blue: 0.998, alpha: 1.0),
    NSColor(calibratedRed: 0.940, green: 0.958, blue: 0.980, alpha: 1.0)
])!
topGradient.draw(in: NSRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height), angle: 90)

let glowPath = NSBezierPath(ovalIn: NSRect(x: 80, y: 230, width: 290, height: 185))
NSColor(calibratedRed: 0.230, green: 0.580, blue: 0.950, alpha: 0.070).setFill()
glowPath.fill()

let folderGlow = NSBezierPath(ovalIn: NSRect(x: 530, y: 230, width: 290, height: 185))
NSColor(calibratedRed: 0.060, green: 0.650, blue: 0.840, alpha: 0.060).setFill()
folderGlow.fill()

let chevron = NSBezierPath()
chevron.move(to: NSPoint(x: 420, y: 388))
chevron.line(to: NSPoint(x: 488, y: 322))
chevron.line(to: NSPoint(x: 420, y: 256))
chevron.lineWidth = 14
chevron.lineCapStyle = .round
chevron.lineJoinStyle = .round
NSColor(calibratedRed: 0.150, green: 0.160, blue: 0.180, alpha: 0.92).setStroke()
chevron.stroke()

drawCentered(
    "Drag QuickDoc to Applications",
    in: NSRect(x: 160, y: 112, width: 580, height: 38),
    font: .systemFont(ofSize: 25, weight: .semibold),
    color: NSColor(calibratedRed: 0.120, green: 0.130, blue: 0.155, alpha: 1.0)
)

drawCentered(
    "拖动QuickDoc至应用文件夹完成安装",
    in: NSRect(x: 160, y: 76, width: 580, height: 32),
    font: .systemFont(ofSize: 19, weight: .medium),
    color: NSColor(calibratedRed: 0.310, green: 0.335, blue: 0.380, alpha: 1.0)
)

NSGraphicsContext.restoreGraphicsState()

guard
    let pngData = canvas.representation(using: .png, properties: [:])
else {
    fputs("Failed to render DMG background image.\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Failed to write DMG background image: \(error)\n", stderr)
    exit(1)
}
