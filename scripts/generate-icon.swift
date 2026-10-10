import AppKit

// Original vector artwork: three endpoints joined by a continuous U-shaped connection.
// Layer canvases stay unmasked. Icon Composer supplies the macOS outline and materials.
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func render(_ name: String, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(
        to: destination.appendingPathComponent(name + ".png"))
}

func connection() {
    NSColor.white.setStroke()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 322, y: 654))
    path.line(to: NSPoint(x: 322, y: 440))
    path.curve(
        to: NSPoint(x: 512, y: 312), controlPoint1: NSPoint(x: 322, y: 347), controlPoint2: NSPoint(x: 402, y: 312))
    path.curve(
        to: NSPoint(x: 702, y: 440), controlPoint1: NSPoint(x: 622, y: 312), controlPoint2: NSPoint(x: 702, y: 347))
    path.line(to: NSPoint(x: 702, y: 654))
    path.lineWidth = 58
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func endpoints() {
    NSColor.white.setFill()
    for rect in [
        NSRect(x: 226, y: 566, width: 192, height: 192),
        NSRect(x: 606, y: 566, width: 192, height: 192),
        NSRect(x: 398, y: 218, width: 228, height: 202),
    ] {
        NSBezierPath(roundedRect: rect, xRadius: 54, yRadius: 54).fill()
    }
}

try render("Connection") { connection() }
try render("Endpoints") { endpoints() }
try render("BrandMark") {
    connection()
    endpoints()
}

// A portable preview/fallback, distinct from the native layered document.
try render("Farcast-preview") {
    let tile = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 186, yRadius: 186)
    NSGradient(colors: [
        NSColor(srgbRed: 0.28, green: 0.42, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.12, green: 0.22, blue: 0.67, alpha: 1),
    ])!.draw(in: tile, angle: -65)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.04, green: 0.10, blue: 0.32, alpha: 0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 16
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    connection()
    endpoints()
    NSGraphicsContext.restoreGraphicsState()
}
