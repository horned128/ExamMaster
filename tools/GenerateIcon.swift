import AppKit

let target = CommandLine.arguments[1]
let color = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "#2F6E70"
let hex = Int(color.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x2F6E70
let teal = NSColor(calibratedRed: CGFloat((hex >> 16) & 255) / 255,
                   green: CGFloat((hex >> 8) & 255) / 255,
                   blue: CGFloat(hex & 255) / 255, alpha: 1)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
teal.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
NSColor.white.withAlphaComponent(0.14).setStroke()
for radius in [270.0, 345.0, 430.0] {
    let ring = NSBezierPath(ovalIn: NSRect(x: 512-radius, y: 512-radius, width: radius*2, height: radius*2))
    ring.lineWidth = 12
    ring.stroke()
}
NSColor.white.setStroke()
let book = NSBezierPath()
book.lineWidth = 26
book.lineCapStyle = .round
book.lineJoinStyle = .round
book.move(to: NSPoint(x: 512, y: 320))
book.line(to: NSPoint(x: 512, y: 674))
book.curve(to: NSPoint(x: 258, y: 699), controlPoint1: NSPoint(x: 430, y: 727), controlPoint2: NSPoint(x: 340, y: 719))
book.line(to: NSPoint(x: 258, y: 354))
book.curve(to: NSPoint(x: 512, y: 320), controlPoint1: NSPoint(x: 345, y: 370), controlPoint2: NSPoint(x: 430, y: 365))
book.curve(to: NSPoint(x: 766, y: 354), controlPoint1: NSPoint(x: 592, y: 365), controlPoint2: NSPoint(x: 679, y: 370))
book.line(to: NSPoint(x: 766, y: 699))
book.curve(to: NSPoint(x: 512, y: 674), controlPoint1: NSPoint(x: 680, y: 719), controlPoint2: NSPoint(x: 595, y: 727))
book.stroke()
NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.48, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 468, y: 490, width: 88, height: 88)).fill()
NSGraphicsContext.restoreGraphicsState()
// A JPEG round-trip drops the alpha channel before encoding the App Store PNG.
let opaque = NSBitmapImageRep(data: bitmap.representation(using: .jpeg, properties: [.compressionFactor: 1.0])!)!
try opaque.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: target))
