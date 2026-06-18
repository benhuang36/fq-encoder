#!/usr/bin/env swift
//
// Generates FQEncoder's app icon and menu-bar (tray) icon into the asset
// catalog. Run from the repo root:  swift scripts/make_icons.swift
//
import AppKit

let root = FileManager.default.currentDirectoryPath
let assets = "\(root)/FQEncoder/Assets.xcassets"
let appIconSet = "\(assets)/AppIcon.appiconset"
let traySet = "\(assets)/TrayIcon.imageset"

// App gradient (matches ContentView): top-left → bottom-right.
let topColor = NSColor(srgbRed: 0.36, green: 0.30, blue: 0.86, alpha: 1)
let bottomColor = NSColor(srgbRed: 0.78, green: 0.34, blue: 0.72, alpha: 1)

// MARK: - Drawing helpers

/// A 4-point "sparkle" star centred at `c` with tip radius `r`. Edges bow
/// toward the centre (control points at `c`) to give the pinched-star look.
func sparkle(_ c: NSPoint, _ r: CGFloat) -> NSBezierPath {
    let tips = [NSPoint(x: c.x, y: c.y + r), NSPoint(x: c.x + r, y: c.y),
                NSPoint(x: c.x, y: c.y - r), NSPoint(x: c.x - r, y: c.y)]
    let p = NSBezierPath()
    p.move(to: tips[0])
    for i in 0..<4 {
        p.curve(to: tips[(i + 1) % 4], controlPoint1: c, controlPoint2: c)
    }
    p.close()
    return p
}

func roundedFont(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded) {
        return NSFont(descriptor: d, size: size) ?? base
    }
    return base
}

func render(_ px: Int, _ body: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    body(CGFloat(px))
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - App icon

func drawAppIcon(_ s: CGFloat) {
    // Squircle content inset inside the canvas (Apple-style margin + shadow).
    let margin = s * 0.10
    let rect = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let radius = rect.width * 0.2237
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Soft drop shadow.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.shadowBlurRadius = s * 0.03
    shadow.set()

    NSGradient(starting: topColor, ending: bottomColor)!
        .draw(in: squircle, angle: -45)

    // Clear shadow for subsequent draws.
    NSShadow().set()

    // Wordmark "FQ".
    let fontSize = rect.width * 0.40
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: roundedFont(fontSize, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ]
    let text = "FQ" as NSString
    let size = text.size(withAttributes: attrs)
    let origin = NSPoint(x: rect.midX - size.width / 2,
                         y: rect.midY - size.height / 2 - rect.height * 0.02)
    text.draw(at: origin, withAttributes: attrs)

    // Sparkle accents (upper-right large, small companion).
    NSColor.white.setFill()
    sparkle(NSPoint(x: rect.maxX - rect.width * 0.20, y: rect.maxY - rect.height * 0.20),
            rect.width * 0.12).fill()
    NSColor.white.withAlphaComponent(0.85).setFill()
    sparkle(NSPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.34),
            rect.width * 0.05).fill()
}

// MARK: - Tray icon (template: solid black + alpha, system tints it)

func drawTray(_ s: CGFloat) {
    NSColor.black.setFill()
    sparkle(NSPoint(x: s * 0.44, y: s * 0.44), s * 0.40).fill()
    sparkle(NSPoint(x: s * 0.80, y: s * 0.78), s * 0.16).fill()
}

// MARK: - Emit files

func write(_ data: Data, to path: String) {
    try! data.write(to: URL(fileURLWithPath: path))
}

try? FileManager.default.createDirectory(atPath: appIconSet, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: traySet, withIntermediateDirectories: true)

// macOS app icon sizes (pt @scale → px).
let appIcons: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
var seen = Set<String>()
for icon in appIcons where seen.insert("\(icon.px)").inserted || true {
    write(render(icon.px, drawAppIcon), to: "\(appIconSet)/\(icon.name).png")
}

write(render(18, drawTray), to: "\(traySet)/tray.png")
write(render(36, drawTray), to: "\(traySet)/tray@2x.png")
write(render(54, drawTray), to: "\(traySet)/tray@3x.png")

// Contents.json for AppIcon.
func appIconContents() -> String {
    let entries: [(String, String, String)] = [
        ("16x16", "1x", "icon_16x16.png"), ("16x16", "2x", "icon_16x16@2x.png"),
        ("32x32", "1x", "icon_32x32.png"), ("32x32", "2x", "icon_32x32@2x.png"),
        ("128x128", "1x", "icon_128x128.png"), ("128x128", "2x", "icon_128x128@2x.png"),
        ("256x256", "1x", "icon_256x256.png"), ("256x256", "2x", "icon_256x256@2x.png"),
        ("512x512", "1x", "icon_512x512.png"), ("512x512", "2x", "icon_512x512@2x.png"),
    ]
    let images = entries.map {
        "    { \"size\" : \"\($0.0)\", \"idiom\" : \"mac\", \"filename\" : \"\($0.2)\", \"scale\" : \"\($0.1)\" }"
    }.joined(separator: ",\n")
    return "{\n  \"images\" : [\n\(images)\n  ],\n  \"info\" : { \"version\" : 1, \"author\" : \"xcode\" }\n}\n"
}

write(appIconContents().data(using: .utf8)!, to: "\(appIconSet)/Contents.json")

let trayContents = """
{
  "images" : [
    { "idiom" : "universal", "filename" : "tray.png", "scale" : "1x" },
    { "idiom" : "universal", "filename" : "tray@2x.png", "scale" : "2x" },
    { "idiom" : "universal", "filename" : "tray@3x.png", "scale" : "3x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" },
  "properties" : { "template-rendering-intent" : "template" }
}
"""
write(trayContents.data(using: .utf8)!, to: "\(traySet)/Contents.json")

let rootContents = """
{
  "info" : { "version" : 1, "author" : "xcode" }
}
"""
write(rootContents.data(using: .utf8)!, to: "\(assets)/Contents.json")

print("✓ Icons generated into \(assets)")
