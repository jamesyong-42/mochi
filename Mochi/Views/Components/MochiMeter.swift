import SwiftUI

struct MochiMeter: View {
    let label: String
    let value: Double
    let theme: MochiTheme

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 8) {
            // Labels row
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(labelColor)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
            }
            .padding(.horizontal, 4)

            // Track + bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(trackColor)
                        .shadow(color: .black.opacity(isDark ? 0.3 : 0.08), radius: 2, y: 1)

                    // White fill bar
                    Capsule()
                        .fill(.white)
                        .shadow(
                            color: isDark ? .white.opacity(0.4) : .black.opacity(0.1),
                            radius: isDark ? 6 : 4,
                            y: isDark ? 0 : 2
                        )
                        .frame(width: max(0, geo.size.width * value))
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: value)
                }
            }
            .frame(height: 16)
        }
    }

    private var labelColor: Color {
        isDark ? .white.opacity(0.6) : Color(hex: "6b7280") // gray-500
    }

    private var valueColor: Color {
        isDark ? .white.opacity(0.9) : Color(hex: "1f2937") // gray-800
    }

    private var trackColor: Color {
        isDark ? .black.opacity(0.2) : .white.opacity(0.4)
    }
}
