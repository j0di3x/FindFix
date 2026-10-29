// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 FindFix contributors
//
// Draws the DMG window background at 1x and 2x.
// Usage: swift Scripts/make-dmg-background.swift <app-icon.png> <out-dir>
// Layout (points, top-left origin) must match make-dmg.sh:
//   window 640x420, app icon centered at (170,200), Applications at (470,200).

import AppKit

let args = CommandLine.arguments
let appIcon = NSImage(contentsOfFile: args[1])!
let outDir = URL(fileURLWithPath: args[2])
let width: CGFloat = 640
let height: CGFloat = 420

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func sparkle(at p: NSPoint, size s: CGFloat, _ fill: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: p.x, y: p.y - s))
    path.curve(to: NSPoint(x: p.x + s, y: p.y), controlPoint1: NSPoint(x: p.x + s * 0.15, y: p.y - s * 0.15),
               controlPoint2: NSPoint(x: p.x + s * 0.15, y: p.y - s * 0.15))
    path.curve(to: NSPoint(x: p.x, y: p.y + s), controlPoint1: NSPoint(x: p.x + s * 0.15, y: p.y + s * 0.15),
               controlPoint2: NSPoint(x: p.x + s * 0.15, y: p.y + s * 0.15))
    path.curve(to: NSPoint(x: p.x - s, y: p.y), controlPoint1: NSPoint(x: p.x - s * 0.15, y: p.y + s * 0.15),
               controlPoint2: NSPoint(x: p.x - s * 0.15, y: p.y + s * 0.15))
    path.curve(to: NSPoint(x: p.x, y: p.y - s), controlPoint1: NSPoint(x: p.x - s * 0.15, y: p.y - s * 0.15),
               controlPoint2: NSPoint(x: p.x - s * 0.15, y: p.y - s * 0.15))
    fill.setFill()
    path.fill()
}

/// A small document card, rotated around its center.
func fileCard(center c: NSPoint, angle: CGFloat, tint: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: c.x, yBy: c.y)
    t.rotate(byDegrees: angle)
    t.concat()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x1B2340, 0.15)
    shadow.shadowOffset = NSSize(width: 0, height: -2)
    shadow.shadowBlurRadius = 4
    shadow.set()
    NSColor.white.setFill()
    roundedRect(-13, -16, 26, 32, 4).fill()
    NSShadow().set()
    tint.setFill()
    roundedRect(-8, -10, 16, 4, 2).fill()
    color(0xC9D4E6).setFill()
    roundedRect(-8, -3, 16, 3, 1.5).fill()
    roundedRect(-8, 3, 11, 3, 1.5).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawScene() {
    // Background: soft sky-to-mint wash with two glows.
    NSGradient(colors: [color(0xDCE8FF), color(0xD9F3F0)])!
        .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 70)
    NSGradient(colors: [color(0xFFFFFF, 0.55), color(0xFFFFFF, 0)])!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: 40, y: 60, width: 560, height: 300)), relativeCenterPosition: .zero)
    NSGradient(colors: [color(0xB7F0E4, 0.6), color(0xB7F0E4, 0)])!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: 420, y: 230, width: 300, height: 260)), relativeCenterPosition: .zero)

    // Wordmark, top left.
    appIcon.draw(in: NSRect(x: 18, y: 14, width: 36, height: 36))
    NSAttributedString(string: "FindFix", attributes: [
        .font: NSFont.systemFont(ofSize: 21, weight: .semibold),
        .foregroundColor: color(0x1B2340),
    ]).draw(at: NSPoint(x: 58, y: 19))

    // Dashed arrow from the app to Applications, dipping below the labels.
    let accent = color(0x2F6FEB, 0.75)
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 222, y: 268))
    arrow.curve(to: NSPoint(x: 408, y: 262),
                controlPoint1: NSPoint(x: 262, y: 334), controlPoint2: NSPoint(x: 362, y: 336))
    arrow.lineWidth = 2.2
    arrow.lineCapStyle = .round
    arrow.setLineDash([7, 6], count: 2, phase: 0)
    accent.setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 394, y: 264))
    head.line(to: NSPoint(x: 410, y: 259))
    head.line(to: NSPoint(x: 410, y: 276))
    head.lineWidth = 2.2
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Hint.
    let hint = NSAttributedString(string: "Drag FindFix into Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: color(0x1B2340, 0.45),
    ])
    hint.draw(at: NSPoint(x: 320 - hint.size().width / 2, y: 340))

    drawMascot()
}

/// "Fixy": a folder with a face, a check-mark badge and a few files around.
func drawMascot() {
    let cx: CGFloat = 548
    // Ground shadow.
    color(0x1B2340, 0.10).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - 58, y: 392, width: 116, height: 14)).fill()

    fileCard(center: NSPoint(x: 476, y: 382), angle: -18, tint: color(0xFF9F43))
    fileCard(center: NSPoint(x: 618, y: 300), angle: 14, tint: color(0xEE5A7A))
    fileCard(center: NSPoint(x: 612, y: 384), angle: 8, tint: color(0x2F6FEB))

    // Feet.
    color(0x135EAD).setFill()
    roundedRect(cx - 38, 386, 24, 13, 6).fill()
    roundedRect(cx + 14, 386, 24, 13, 6).fill()

    // Folder tab and body.
    color(0x1A73D9).setFill()
    roundedRect(cx - 60, 296, 54, 24, 8).fill()
    let body = roundedRect(cx - 62, 308, 124, 84, 18)
    NSGradient(colors: [color(0x3A97FF), color(0x18C2B4)])!.draw(in: body, angle: -70)
    color(0xFFFFFF, 0.25).setFill()
    roundedRect(cx - 50, 314, 100, 6, 3).fill()

    // Eyes looking toward the arrow.
    for ex in [cx - 22, cx + 22] {
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: ex - 11, y: 330, width: 22, height: 25)).fill()
        color(0x1B2340).setFill()
        NSBezierPath(ovalIn: NSRect(x: ex - 8, y: 335, width: 11, height: 12)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: ex - 6, y: 337, width: 4, height: 4)).fill()
    }
    // Cheeks and smile.
    color(0xFF7BA5, 0.45).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - 46, y: 357, width: 14, height: 8)).fill()
    NSBezierPath(ovalIn: NSRect(x: cx + 32, y: 357, width: 14, height: 8)).fill()
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: cx - 10, y: 364))
    smile.curve(to: NSPoint(x: cx + 10, y: 364),
                controlPoint1: NSPoint(x: cx - 6, y: 373), controlPoint2: NSPoint(x: cx + 6, y: 373))
    smile.lineWidth = 3
    smile.lineCapStyle = .round
    color(0x1B2340).setStroke()
    smile.stroke()

    // Check badge.
    let badge = NSRect(x: cx + 40, y: 286, width: 32, height: 32)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: badge.insetBy(dx: -3, dy: -3)).fill()
    color(0x22C55E).setFill()
    NSBezierPath(ovalIn: badge).fill()
    let check = NSBezierPath()
    check.move(to: NSPoint(x: badge.minX + 9, y: badge.midY))
    check.line(to: NSPoint(x: badge.minX + 14, y: badge.midY + 6))
    check.line(to: NSPoint(x: badge.maxX - 8, y: badge.midY - 6))
    check.lineWidth = 3.5
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor.white.setStroke()
    check.stroke()

    sparkle(at: NSPoint(x: 486, y: 300), size: 8, color(0xFFC94D))
    sparkle(at: NSPoint(x: 600, y: 256), size: 6, color(0xFFC94D))
    sparkle(at: NSPoint(x: 462, y: 340), size: 4, color(0x2F6FEB, 0.6))
}

func render(scale: CGFloat, to url: URL) {
    let pw = Int(width * scale), ph = Int(height * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    // The context already maps points to pixels (rep.size); flip so drawing
    // uses Finder's top-left coordinates.
    ctx.cgContext.translateBy(x: 0, y: height)
    ctx.cgContext.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx.cgContext, flipped: true)
    drawScene()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

render(scale: 1, to: outDir.appendingPathComponent("background.png"))
render(scale: 2, to: outDir.appendingPathComponent("background@2x.png"))
print("Wrote background.png and background@2x.png to \(outDir.path)")
