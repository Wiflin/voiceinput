#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent("build/VoiceInput.iconset")
let legacyIconsetURL = rootURL.appendingPathComponent("AppBundle/VoiceInput.iconset")
let outputURL = rootURL.appendingPathComponent("AppBundle/VoiceInput.icns")

try? fileManager.removeItem(at: iconsetURL)
try? fileManager.removeItem(at: legacyIconsetURL)
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconFile in iconFiles {
    let image = drawIcon(size: iconFile.pixels)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconError.renderFailed(iconFile.name)
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(iconFile.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw IconError.iconutilFailed(process.terminationStatus)
}

enum IconError: Error {
    case renderFailed(String)
    case iconutilFailed(Int32)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    context.clear(rect)

    let inset = size * 0.065
    let backgroundRect = rect.insetBy(dx: inset, dy: inset)
    let radius = size * 0.23
    let backgroundPath = CGPath(
        roundedRect: backgroundRect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )

    context.saveGState()
    context.addPath(backgroundPath)
    context.clip()

    drawBackground(in: context, rect: backgroundRect)
    drawGlow(in: context, size: size)
    drawWaveBars(in: context, size: size)
    drawMicrophone(in: context, size: size)

    context.restoreGState()

    drawInnerHighlight(in: context, path: backgroundPath, size: size)
    return image
}

func drawBackground(in context: CGContext, rect: CGRect) {
    let colors = [
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.17, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.04, green: 0.22, blue: 0.25, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.02, green: 0.07, blue: 0.11, alpha: 1).cgColor
    ] as CFArray

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.56, 1]
    )

    if let gradient {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }
}

func drawGlow(in context: CGContext, size: CGFloat) {
    let center = CGPoint(x: size * 0.36, y: size * 0.65)
    let colors = [
        NSColor(calibratedRed: 0.42, green: 0.95, blue: 0.88, alpha: 0.55).cgColor,
        NSColor(calibratedRed: 0.16, green: 0.58, blue: 0.98, alpha: 0.18).cgColor,
        NSColor(calibratedWhite: 1, alpha: 0).cgColor
    ] as CFArray

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.5, 1]
    )

    if let gradient {
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: size * 0.55,
            options: [.drawsAfterEndLocation]
        )
    }
}

func drawWaveBars(in context: CGContext, size: CGFloat) {
    let weights: [CGFloat] = [0.48, 0.78, 1.0, 0.74, 0.52]
    let barWidth = size * 0.045
    let gap = size * 0.034
    let originX = size * 0.55
    let centerY = size * 0.51
    let maxHeight = size * 0.43
    let minHeight = size * 0.14

    context.saveGState()
    context.setFillColor(NSColor(calibratedRed: 0.35, green: 0.98, blue: 0.88, alpha: 0.90).cgColor)
    context.setShadow(
        offset: .zero,
        blur: size * 0.035,
        color: NSColor(calibratedRed: 0.24, green: 0.88, blue: 0.82, alpha: 0.55).cgColor
    )

    for (index, weight) in weights.enumerated() {
        let height = minHeight + maxHeight * weight
        let x = originX + CGFloat(index) * (barWidth + gap)
        let y = centerY - height / 2
        let rect = CGRect(x: x, y: y, width: barWidth, height: height)
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: barWidth / 2,
            cornerHeight: barWidth / 2,
            transform: nil
        )
        context.addPath(path)
        context.fillPath()
    }

    context.restoreGState()
}

func drawMicrophone(in context: CGContext, size: CGFloat) {
    context.saveGState()

    let bodyRect = CGRect(
        x: size * 0.285,
        y: size * 0.34,
        width: size * 0.20,
        height: size * 0.41
    )
    let bodyPath = CGPath(
        roundedRect: bodyRect,
        cornerWidth: bodyRect.width / 2,
        cornerHeight: bodyRect.width / 2,
        transform: nil
    )

    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.01),
        blur: size * 0.045,
        color: NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.35).cgColor
    )
    context.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.94).cgColor)
    context.addPath(bodyPath)
    context.fillPath()

    context.setFillColor(NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.28, alpha: 0.24).cgColor)
    let shine = CGRect(
        x: bodyRect.minX + bodyRect.width * 0.27,
        y: bodyRect.minY + bodyRect.height * 0.18,
        width: bodyRect.width * 0.16,
        height: bodyRect.height * 0.56
    )
    context.fillEllipse(in: shine)

    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.88).cgColor)
    context.setLineWidth(size * 0.035)
    context.setLineCap(.round)

    let arcRect = CGRect(
        x: size * 0.235,
        y: size * 0.265,
        width: size * 0.30,
        height: size * 0.31
    )
    context.addArc(
        center: CGPoint(x: arcRect.midX, y: arcRect.midY + arcRect.height * 0.08),
        radius: arcRect.width / 2,
        startAngle: .pi,
        endAngle: 0,
        clockwise: true
    )
    context.strokePath()

    context.move(to: CGPoint(x: size * 0.385, y: size * 0.275))
    context.addLine(to: CGPoint(x: size * 0.385, y: size * 0.19))
    context.strokePath()

    context.move(to: CGPoint(x: size * 0.30, y: size * 0.19))
    context.addLine(to: CGPoint(x: size * 0.47, y: size * 0.19))
    context.strokePath()

    context.restoreGState()
}

func drawInnerHighlight(in context: CGContext, path: CGPath, size: CGFloat) {
    context.saveGState()
    context.addPath(path)
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.16).cgColor)
    context.setLineWidth(size * 0.018)
    context.strokePath()
    context.restoreGState()
}
