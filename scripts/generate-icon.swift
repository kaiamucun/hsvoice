import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvas = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

image.lockFocus()
guard let context = NSGraphicsContext.current else {
    fputs("Could not create a graphics context\n", stderr)
    exit(1)
}
context.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(origin: .zero, size: canvas).fill()

let backgroundRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 218, yRadius: 218)
let gradient = NSGradient(colors: [
    NSColor(red: 0.08, green: 0.80, blue: 0.69, alpha: 1),
    NSColor(red: 0.09, green: 0.49, blue: 0.78, alpha: 1),
    NSColor(red: 0.09, green: 0.23, blue: 0.47, alpha: 1)
])!
gradient.draw(in: backgroundPath, angle: -45)

let innerPath = NSBezierPath(roundedRect: NSRect(x: 158, y: 158, width: 708, height: 708), xRadius: 166, yRadius: 166)
innerPath.lineWidth = 4
NSColor.white.withAlphaComponent(0.12).setStroke()
innerPath.stroke()

let bars: [(x: CGFloat, y: CGFloat, height: CGFloat, alpha: CGFloat)] = [
    (240, 450, 124, 0.82),
    (336, 350, 324, 0.90),
    (432, 262, 500, 1.00),
    (528, 328, 368, 1.00),
    (624, 388, 248, 0.90),
    (720, 450, 124, 0.82)
]

for bar in bars {
    let path = NSBezierPath(
        roundedRect: NSRect(x: bar.x, y: bar.y, width: 64, height: bar.height),
        xRadius: 32,
        yRadius: 32
    )
    NSColor.white.withAlphaComponent(bar.alpha).setFill()
    path.fill()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode the icon as PNG\n", stderr)
    exit(1)
}

try png.write(to: outputURL, options: .atomic)

