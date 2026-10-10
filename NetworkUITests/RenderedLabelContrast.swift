import UIKit

/// Local rendered-label regression check, not a whole-screen WCAG audit.
/// Shared by the calibrated disabled-footer test and prominent mock actions.
enum RenderedLabelContrast {
    static func measure(in image: CGImage, window: CGRect, button: CGRect) -> Double {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return 0 }
        let scaleX = CGFloat(image.width) / window.width
        let scaleY = CGFloat(image.height) / window.height
        func luminance(x: CGFloat, y: CGFloat) -> Double {
            let column = Int((x - window.minX) * scaleX)
            let row = Int((y - window.minY) * scaleY)
            guard column >= 0, column < image.width, row >= 0, row < image.height else { return 0 }
            let offset = (row * image.width + column) * 4
            let rgb = (0..<3).map { index -> Double in
                let channel = Double(pixels[offset + index]) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
        }
        // AX includes the footer's padding and sometimes the bottom safe area.
        // Its midpoint can miss normal-size text entirely. Inspect the label's
        // upper-middle region, excluding rounded edges and the home indicator,
        // and compare glyph/background pixels within each rendered row.
        var highest = 1.0
        for y in stride(from: button.minY + button.height * 0.2,
                        through: button.minY + button.height * 0.55, by: 1 / scaleY) {
            var darkest = 1.0
            var brightest = 0.0
            for x in stride(from: button.minX + button.width * 0.25, through: button.minX + button.width * 0.75, by: 1 / scaleX) {
                let pixel = luminance(x: x, y: y)
                darkest = min(darkest, pixel)
                brightest = max(brightest, pixel)
            }
            highest = max(highest, (brightest + 0.05) / (darkest + 0.05))
        }
        return highest
    }
}
