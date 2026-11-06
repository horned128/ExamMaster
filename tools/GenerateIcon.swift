import AppKit

// swift tools/GenerateIcon.swift Qualifications/<id>/qualification.json Assets.xcassets/<Icon>.appiconset/AppIcon.png [--check]
// Uses the same original face geometry and qualification color as the native mascot.

struct IconGenerationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func fail(_ message: String) throws -> Never { throw IconGenerationError(message: message) }

func color(_ hex: String) throws -> NSColor {
    guard hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
          let value = Int(hex.dropFirst(), radix: 16) else { try fail("Invalid color: \(hex). Use #RRGGBB.") }
    return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                   green: CGFloat((value >> 8) & 255) / 255,
                   blue: CGFloat(value & 255) / 255, alpha: 1)
}

func path(_ shape: [String: String]) throws -> NSBezierPath {
    if shape["type"] == "circle" {
        guard let x = Double(shape["cx"] ?? ""), let y = Double(shape["cy"] ?? ""),
              let radius = Double(shape["r"] ?? "") else { try fail("Invalid face circle") }
        return NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
    guard shape["type"] == "path", let data = shape["d"] else { try fail("Unsupported face shape") }
    let pattern = try NSRegularExpression(pattern: "[-+]?\\d+(?:\\.\\d+)?(?:[eE][-+]?\\d+)?|[A-Za-z]")
    let tokens = pattern.matches(in: data, range: NSRange(data.startIndex..., in: data)).map {
        String(data[Range($0.range, in: data)!])
    }
    let result = NSBezierPath()
    var index = 0
    while index < tokens.count {
        let command = tokens[index]
        guard let count = ["M": 2, "L": 2, "C": 6, "Q": 4, "Z": 0][command],
              index + count < tokens.count else { try fail("Unsupported/incomplete face path: \(command)") }
        let values = tokens[(index + 1)..<(index + 1 + count)].compactMap(Double.init)
        guard values.count == count else { try fail("Invalid face path coordinates") }
        func point(_ offset: Int) -> NSPoint { NSPoint(x: values[offset], y: values[offset + 1]) }
        switch command {
        case "M": result.move(to: point(0))
        case "L": result.line(to: point(0))
        case "C": result.curve(to: point(4), controlPoint1: point(0), controlPoint2: point(2))
        case "Q":
            let start = result.currentPoint, control = point(0), end = point(2)
            result.curve(to: end,
                         controlPoint1: NSPoint(x: start.x + (control.x - start.x) * 2 / 3,
                                                y: start.y + (control.y - start.y) * 2 / 3),
                         controlPoint2: NSPoint(x: end.x + (control.x - end.x) * 2 / 3,
                                                y: end.y + (control.y - end.y) * 2 / 3))
        default: result.close()
        }
        index += count + 1
    }
    return result
}

func roundedFont(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .black)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func titleLines(_ title: String) -> [String] {
    if title.contains("\n") { return title.components(separatedBy: "\n") }
    if (title as NSString).size(withAttributes: [.font: roundedFont(140)]).width <= labelTextWidth { return [title] }
    let characters = Array(title)
    let middle = (characters.count + 1) / 2
    let spaces = characters.indices.filter { characters[$0].isWhitespace && $0 > 0 && $0 < characters.count - 1 }
    let split = spaces.min { abs($0 - middle) < abs($1 - middle) } ?? middle
    return [String(characters[..<split]), String(characters[split...])].map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

let labelTextWidth: CGFloat = 760

/// Piyo Pop: brand-yellow ground shared by every qualification app, the mascot face in its
/// qualification colour, and a puffy white label whose depth edge carries the qualification accent.
func generate(configuration: URL) throws -> Data {
    guard let config = try JSONSerialization.jsonObject(with: Data(contentsOf: configuration)) as? [String: Any],
          let name = config["name"] as? String, let accentHex = config["accentHex"] as? String else {
        try fail("qualification.json requires name and accentHex")
    }
    let title = (config["iconTitle"] as? String ?? name).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { try fail("The qualification name / iconTitle must not be empty") }
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let faceURL = root.appendingPathComponent("design-system/exammaster/mascot/chicken-face.json")
    guard let face = try JSONSerialization.jsonObject(with: Data(contentsOf: faceURL)) as? [String: Any],
          let baseFill = face["baseFill"] as? String, let shapes = face["shapes"] as? [[String: String]] else {
        try fail("Run python3 tools/GenerateMascot.py first")
    }
    let baseColor = try color(config["mascotBaseHex"] as? String ?? baseFill)
    let accent = try color(accentHex)
    let ink = try color("#2D2618")
    let faceInk = "#243B3A"
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                  bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4096, bitsPerPixel: 32),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { try fail("Could not create an opaque bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.setShouldAntialias(true)

    // Ground: brand yellow, slightly lighter at the top, with a soft cream halo behind the face.
    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    NSGradient(starting: try color("#FFC83D"), ending: try color("#FFDA6B"))!.draw(in: canvas, angle: 90)
    NSGradient(colors: [try color("#FFF1C7").withAlphaComponent(0.95), try color("#FFF1C7").withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 512, y: 600), radius: 0, toCenter: NSPoint(x: 512, y: 600), radius: 400,
              options: [])

    // Face, drawn from the shared mascot geometry (y-down SVG space, ~76…165 × 16…126).
    context.saveGState()
    context.translateBy(x: 512, y: 948)
    context.scaleBy(x: 5.1, y: -5.1)
    context.translateBy(x: -128, y: -12)
    for shape in shapes {
        let outline = try path(shape)
        if let fill = shape["fill"], fill != "none" {
            (fill == baseFill ? baseColor : fill == faceInk ? ink : try color(fill)).setFill()
            outline.fill()
        }
        if let stroke = shape["stroke"], stroke != "none" {
            (stroke == faceInk ? ink : try color(stroke)).setStroke()
            outline.lineWidth = Double(shape["stroke-width"] ?? "1") ?? 1
            outline.lineCapStyle = shape["stroke-linecap"] == "round" ? .round : .butt
            outline.lineJoinStyle = shape["stroke-linejoin"] == "round" ? .round : .miter
            outline.stroke()
        }
    }
    context.restoreGState()

    let lines = titleLines(title)
    guard (1...2).contains(lines.count), lines.allSatisfy({ !$0.isEmpty }) else {
        try fail("Use at most two non-empty lines in iconTitle")
    }
    var fontSize: CGFloat = lines.count == 1 ? 150 : 108
    let minimum: CGFloat = 72
    while fontSize >= minimum {
        if lines.allSatisfy({ ($0 as NSString).size(withAttributes: [.font: roundedFont(fontSize)]).width <= labelTextWidth }) { break }
        fontSize -= 2
    }
    guard fontSize >= minimum else { try fail("Name is too long for a readable icon. Set a shorter iconTitle.") }

    // Puffy label: white face over an accent-coloured depth edge, like the in-app PuffyButtonStyle.
    let lineHeight = fontSize * 1.12
    let textHeight = lineHeight * CGFloat(lines.count)
    let labelHeight = textHeight + 64
    let labelTop: CGFloat = 400
    let label = NSRect(x: 96, y: labelTop - labelHeight, width: 832, height: labelHeight)
    let radius: CGFloat = min(72, labelHeight / 2)
    accent.setFill()
    NSBezierPath(roundedRect: label.offsetBy(dx: 0, dy: -22), xRadius: radius, yRadius: radius).fill()
    NSColor.white.setFill()
    let labelPath = NSBezierPath(roundedRect: label, xRadius: radius, yRadius: radius)
    labelPath.fill()
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: roundedFont(fontSize),
                                                   .foregroundColor: ink, .paragraphStyle: paragraph]
    let font = roundedFont(fontSize)
    let glyphHeight = font.ascender - font.descender
    for (index, line) in lines.enumerated() {
        let rowTop = label.midY + textHeight / 2 - CGFloat(index) * lineHeight
        let y = rowTop - lineHeight + (lineHeight - glyphHeight) / 2
        (line as NSString).draw(in: NSRect(x: label.minX, y: y, width: label.width, height: glyphHeight),
                                withAttributes: attributes)
    }
    guard let png = bitmap.representation(using: .png, properties: [:]) else { try fail("PNG encoding failed") }
    return png
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--check") else {
        try fail("Usage: swift tools/GenerateIcon.swift <qualification.json> <AppIcon.png> [--check]")
    }
    let png = try generate(configuration: URL(fileURLWithPath: arguments[0]))
    let output = URL(fileURLWithPath: arguments[1])
    if arguments.contains("--check") {
        guard try Data(contentsOf: output) == png else { try fail("Icon differs from qualification settings. Regenerate it.") }
        print("Verified Piyo Pop icon: \(arguments[1])")
    } else {
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: output, options: .atomic)
        print("Generated opaque 1024px Piyo Pop icon: \(arguments[1])")
    }
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
