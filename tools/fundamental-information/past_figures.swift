import Foundation
import PDFKit
import AppKit

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 8,
      let pdf = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])),
      let page = pdf.page(at: CommandLine.arguments.count == 3 ? 5 : Int(CommandLine.arguments[2])!) else {
    fputs("Usage: past_figures input.pdf output.png OR input.pdf page x y width height output.png\n", stderr)
    exit(1)
}
let image = page.thumbnail(of: NSSize(width: 1770, height: 2500), for: .mediaBox)
guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let crop = cg.cropping(to: CommandLine.arguments.count == 3
          ? CGRect(x: 235, y: 700, width: 1350, height: 1700)
          : CGRect(x: Int(CommandLine.arguments[3])!, y: Int(CommandLine.arguments[4])!,
                   width: Int(CommandLine.arguments[5])!, height: Int(CommandLine.arguments[6])!)) else {
    fputs("Unable to crop diagram\n", stderr)
    exit(1)
}
let rep = NSBitmapImageRep(cgImage: crop)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
let output = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : CommandLine.arguments[7]
try data.write(to: URL(fileURLWithPath: output), options: .atomic)
print("Saved \(crop.width)x\(crop.height)")
