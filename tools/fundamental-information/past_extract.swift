import Foundation
import PDFKit

guard CommandLine.arguments.count == 3,
      let pdf = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    fputs("Usage: past_extract input.pdf output.txt\n", stderr)
    exit(1)
}
var pages: [String] = []
for i in 0..<pdf.pageCount {
    guard let page = pdf.page(at: i) else { continue }
    pages.append("\n--- PAGE \(i + 1) ---\n" + (page.string ?? ""))
}
try pages.joined(separator: "\n").write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
print("\(pdf.pageCount) pages")
