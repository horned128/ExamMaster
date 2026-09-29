import SwiftUI

enum Palette {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)

    static func accent(_ hex: String) -> Color {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x2F6E70
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255)
    }
}

struct Surface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct Metric: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        Surface {
            Image(systemName: symbol).foregroundStyle(.tint).font(.title3)
            Text(value).font(.title2.bold()).contentTransition(.numericText())
            Text(title).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
