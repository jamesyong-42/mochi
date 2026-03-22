import SwiftUI

// MARK: - Tweakable State

@Observable
final class BackgroundTweaks {
    var windowOpacity: Double = 1.0
}

// MARK: - Dev Panel View

struct DevTweakPanel: View {
    @State private var tweaks = BackgroundTweaks()

    var body: some View {
        @Bindable var tweaks = tweaks

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Circle().fill(.red.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(.orange.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(.green.opacity(0.8)).frame(width: 8, height: 8)
                Spacer()
                Text("DEV TWEAKS")
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 32, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Window opacity
                    tweakSection("WINDOW OPACITY") {
                        tweakSlider(value: $tweaks.windowOpacity, range: 0.3...1.0, label: String(format: "%.0f%%", tweaks.windowOpacity * 100))
                    }

                    // Reset
                    Button {
                        tweaks.windowOpacity = 1.0
                    } label: {
                        Text("Reset All")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    // Print
                    Button {
                        print("""
                        === Dev Tweaks ===
                        Window Opacity: \(String(format: "%.2f", tweaks.windowOpacity))
                        ====================
                        """)
                    } label: {
                        Text("Print Values")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
        .frame(width: 240)
        .modifier(GlassBackgroundModifier())
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
    }

    private func tweakSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .tracking(1)
                .foregroundStyle(.tertiary)
            content()
        }
    }

    private func tweakSlider(value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        HStack(spacing: 8) {
            Slider(value: value, in: range)
                .controlSize(.mini)
            Text(label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Glass Background Modifier

private struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        #else
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        #endif
    }
}
