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

func titleLines(_ title: String) -> [String] {
    if title.contains("\n") { return title.components(separatedBy: "\n") }
    let font = NSFont.systemFont(ofSize: 144, weight: .heavy)
    if (title as NSString).size(withAttributes: [.font: font]).width <= 864 { return [title] }
    let characters = Array(title)
    let middle = (characters.count + 1) / 2
    let spaces = characters.indices.filter { characters[$0].isWhitespace && $0 > 0 && $0 < characters.count - 1 }
    let split = spaces.min { abs($0 - middle) < abs($1 - middle) } ?? middle
    return [String(characters[..<split]), String(characters[split...])].map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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
    let ink = try color("#243B3A")
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                  bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4096, bitsPerPixel: 32),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { try fail("Could not create an opaque bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.setShouldAntialias(true)
    NSColor(srgbRed: 0.90 + accent.redComponent * 0.10,
            green: 0.90 + accent.greenComponent * 0.10,
            blue: 0.90 + accent.blueComponent * 0.10, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    context.saveGState()
    context.translateBy(x: 512, y: 952)
    context.scaleBy(x: 4.8, y: -4.8)
    context.translateBy(x: -128, y: -15)
    for shape in shapes {
        let outline = try path(shape)
        if let fill = shape["fill"], fill != "none" {
            (fill == baseFill ? baseColor : try color(fill)).setFill()
            outline.fill()
        }
        if let stroke = shape["stroke"], stroke != "none" {
            try color(stroke).setStroke()
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
    var fontSize: CGFloat = 144
    while fontSize >= 72 {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
        if lines.allSatisfy({ ($0 as NSString).size(withAttributes: [.font: font]).width <= 864 }) { break }
        fontSize -= 2
    }
    guard fontSize >= 72 else { try fail("Name is too long for a readable icon. Set a shorter iconTitle.") }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
                                                   .foregroundColor: ink, .paragraphStyle: paragraph]
    let lineHeight = fontSize * 1.15
    let blockHeight = lineHeight * CGFloat(lines.count)
    for (index, line) in lines.enumerated() {
        let y = 212 + blockHeight / 2 - CGFloat(index + 1) * lineHeight
        (line as NSString).draw(in: NSRect(x: 80, y: y, width: 864, height: lineHeight), withAttributes: attributes)
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
        print("Verified chicken face icon: \(arguments[1])")
    } else {
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: output, options: .atomic)
        print("Generated opaque 1024px chicken face icon: \(arguments[1])")
    }
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
