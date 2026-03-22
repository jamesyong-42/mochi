import SwiftUI

struct MochiMeter: View {
    let label: String
    let value: Double
    let theme: MochiTheme

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isDark ? .black.opacity(0.2) : .black.opacity(0.05))

                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .frame(width: max(0, geo.size.width * value))
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: value)
                }
            }
            .frame(height: 16)
        }
    }
}
