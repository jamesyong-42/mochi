import SwiftUI

// MARK: - Tweakable State

@Observable
final class BackgroundTweaks {
    var windowOpacity: Double = 1.0

    // Glass style: 0 = regular, 1 = clear, 2 = identity (off)
    var glassLevel: Int = 0

    // Tint
    var tintEnabled: Bool = false
    var tintHue: Double = 0.6 // 0...1 hue wheel
    var tintOpacity: Double = 0.5

    var glassStyle: Glass {
        let base: Glass = switch glassLevel {
        case 1: .clear
        case 2: .identity
        default: .regular
        }
        if tintEnabled {
            return base.tint(Color(hue: tintHue, saturation: 0.7, brightness: 0.9).opacity(tintOpacity))
        }
        return base
    }

    static let glassLevelNames = ["Regular", "Clear", "Identity"]
}

// MARK: - Dev Panel View

struct DevTweakPanel: View {
    @Environment(BackgroundTweaks.self) private var tweaks

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
                    // Glass style
                    tweakSection("GLASS STYLE") {
                        Picker("", selection: $tweaks.glassLevel) {
                            ForEach(Array(BackgroundTweaks.glassLevelNames.enumerated()), id: \.offset) { i, name in
                                Text(name).tag(i)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    // Tint toggle + controls
                    tweakSection("TINT") {
                        Toggle("Enabled", isOn: $tweaks.tintEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)

                        if tweaks.tintEnabled {
                            HStack(spacing: 8) {
                                Text("Hue")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .leading)
                                Slider(value: $tweaks.tintHue, in: 0...1)
                                    .controlSize(.mini)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hue: tweaks.tintHue, saturation: 0.7, brightness: 0.9))
                                    .frame(width: 16, height: 16)
                            }

                            HStack(spacing: 8) {
                                Text("Alpha")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .leading)
                                Slider(value: $tweaks.tintOpacity, in: 0...1)
                                    .controlSize(.mini)
                                Text(String(format: "%.0f%%", tweaks.tintOpacity * 100))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }

                    // Window opacity
                    tweakSection("WINDOW OPACITY") {
                        tweakSlider(value: $tweaks.windowOpacity, range: 0.3...1.0, label: String(format: "%.0f%%", tweaks.windowOpacity * 100))
                    }

                    // Reset
                    Button {
                        let d = BackgroundTweaks()
                        tweaks.windowOpacity = d.windowOpacity
                        tweaks.glassLevel = d.glassLevel
                        tweaks.tintEnabled = d.tintEnabled
                        tweaks.tintHue = d.tintHue
                        tweaks.tintOpacity = d.tintOpacity
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
                        === Glass Tweaks ===
                        Style: \(BackgroundTweaks.glassLevelNames[tweaks.glassLevel])
                        Tint: \(tweaks.tintEnabled ? "hue=\(String(format: "%.2f", tweaks.tintHue)) alpha=\(String(format: "%.2f", tweaks.tintOpacity))" : "off")
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
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
