import Foundation
import PDFKit
import Vision
import AppKit

// OCR locates question boundaries and assists transcription. Only individually
// checked editorial text is promoted to native display; pending text retains
// its original crop. Grading comes only from the official answer document.
let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, let document = PDFDocument(url: URL(fileURLWithPath: arguments[0])) else {
    fputs("Usage: ReadBooklet input.pdf output.json\n", stderr); exit(1)
}
var pages: [[String: Any]] = []
for index in 0..<document.pageCount {
    let result: [String: Any] = try autoreleasepool {
        guard let page = document.page(at: index) else { throw NSError(domain: "PDF", code: 1) }
        let image = page.thumbnail(of: NSSize(width: 1500, height: 2122), for: .mediaBox)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw NSError(domain: "Image", code: 1) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = false
        request.usesCPUOnly = true
        try VNImageRequestHandler(cgImage: cg).perform([request])
        let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return ["text": candidate.string, "confidence": candidate.confidence,
                    "box": [box.minX, 1 - box.maxY, box.maxX, 1 - box.minY]]
        }
        return ["page": index + 1, "lines": lines]
    }
    pages.append(result)
}
let data = try JSONSerialization.data(withJSONObject: ["file": URL(fileURLWithPath: arguments[0]).lastPathComponent,
                                                      "pages": pages], options: [.sortedKeys, .withoutEscapingSlashes])
try data.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
print(URL(fileURLWithPath: arguments[0]).lastPathComponent, pages.count)
