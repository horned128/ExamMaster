import SwiftUI

/// Wrap each source line separately so continuations retain their indentation
/// and share a line number. Font and wrapping choices also apply in the reader.
struct StudyCodeView: View {
    let source: String
    var largeText = false
    @AppStorage("fundamentalCodeWrap") private var wraps = true
    @AppStorage("fundamentalCodeSize") private var size = "standard"
    @ScaledMetric(relativeTo: .body) private var standardSize: CGFloat = 15
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var fontSize: CGFloat {
        standardSize * (size == "small" ? 13.0 / 15 : size == "large" ? 17.0 / 15 : 1) * (largeText ? 1.12 : 1)
    }
    private var lines: [String] {
        source.replacingOccurrences(of: "\t", with: "    ").components(separatedBy: "\n")
    }
    private var gutter: CGFloat { CGFloat(String(lines.count).count) * fontSize * 0.65 + 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let controls = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            controls {
                Text(wraps ? "画面幅で折り返し" : "行をそのまま表示")
                    .font(.caption).foregroundStyle(Palette.muted)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Menu {
                    Picker("コードの文字サイズ", selection: $size) {
                        Text("小さめ").tag("small")
                        Text("標準").tag("standard")
                        Text("大きめ").tag("large")
                    }
                    Toggle("折り返す", isOn: $wraps)
                } label: {
                    Label("表示設定", systemImage: "textformat.size")
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
                .accessibilityIdentifier("codeDisplaySettings")
            }
            Group {
                if wraps {
                    sourceLines(wrapped: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("wrappedStudyCode")
                } else {
                    ScrollView(.horizontal) { sourceLines(wrapped: false) }
                        .accessibilityIdentifier("unwrappedStudyCode")
                }
            }
            .background(Palette.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("contentMonospace")
        }
    }

    private func sourceLines(wrapped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines.indices, id: \.self) { index in
                let line = lines[index]
                let indentation = line.prefix(while: { $0 == " " }).count
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: fontSize * 0.78, design: .monospaced))
                        .foregroundStyle(Palette.muted).frame(width: gutter, alignment: .trailing)
                        .accessibilityHidden(true)
                    Text(line.isEmpty ? " " : String(line.dropFirst(indentation)))
                        .font(.system(size: fontSize, design: .monospaced))
                        .lineSpacing(4)
                        .padding(.leading, CGFloat(indentation) * min(fontSize * 0.25, 5))
                        .frame(maxWidth: wrapped ? .infinity : nil, alignment: .leading)
                        .fixedSize(horizontal: !wrapped, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("codeLine-\(index)")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(index + 1)行目、\(line)")
                .accessibilityIdentifier("codeSourceLine-\(index)")
            }
        }
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contentCodeText")
    }
}
