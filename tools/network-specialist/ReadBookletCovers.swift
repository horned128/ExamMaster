import Foundation
import PDFKit
import Vision
import AppKit

// OCR is evidence for coverage review only. Never import OCR into the question bank.
var results: [[String: Any]] = []
for path in CommandLine.arguments.dropFirst() {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)), let page = doc.page(at: 0) else {
        fputs("Cannot read \(path)\n", stderr); exit(1)
    }
    let image = page.thumbnail(of: NSSize(width: 1400, height: 2000), for: .mediaBox)
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ja-JP", "en-US"]
    request.usesCPUOnly = true
    do { try VNImageRequestHandler(cgImage: cg).perform([request]) }
    catch { fputs("Cover OCR failed (review the PDF visually instead): \(error)\n", stderr); exit(1) }
    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    results.append(["file": URL(fileURLWithPath: path).lastPathComponent, "coverText": text, "pages": doc.pageCount])
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
FileHandle.standardOutput.write(data)
