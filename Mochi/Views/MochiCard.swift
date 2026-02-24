import SwiftUI

struct MochiCard: View {
    @Environment(VMManager.self) private var vmManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    let config: VMConfig
    let state: VMState
    var onEdit: () -> Void

    @State private var isHovering = false
    @State private var showDeleteConfirmation = false
    @State private var cpuUsage: Double = 0
    @State private var ramUsage: Double = 0
    @State private var uptimeSeconds: Int = 0
    @State private var uptimeTimer: Timer?

    private var theme: MochiTheme {
        MochiTheme.forKey(config.colorKey)
    }

    private var isActive: Bool { state == .running }
    private var isDark: Bool { colorScheme == .dark }

    // MARK: - Design Constants

    private let wrapperRadius: CGFloat = 48
    private let wrapperPadding: CGFloat = 32
    private let innerGlow: CGFloat = 20
    private let outerShadow: CGFloat = 30

    private var innerRadius: CGFloat {
        max(8, wrapperRadius - wrapperPadding)
    }

    var body: some View {
        VStack(spacing: 0) {
            innerContent
                .padding(24)
                .frame(minHeight: 320)
                .background(innerFillColor)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius))
                .overlay {
                    // Inner shadow glow
                    RoundedRectangle(cornerRadius: innerRadius)
                        .stroke(.clear, lineWidth: 0)
                        .shadow(
                            color: isActive
                                ? (isDark ? .black.opacity(0.5) : .white.opacity(0.8))
                                : .black.opacity(0.05),
                            radius: isActive ? innerGlow : 10,
                            y: isActive ? innerGlow / 4 : 2
                        )
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius))
                }
                .overlay {
                    // Dashed border for dark+inactive
                    if isDark && !isActive {
                        RoundedRectangle(cornerRadius: innerRadius)
                            .strokeBorder(
                                Color.white.opacity(0.1),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    }
                }
        }
        .padding(wrapperPadding)
        .background(outerWrapperColor)
        .clipShape(RoundedRectangle(cornerRadius: wrapperRadius))
        .shadow(
            color: isDark
                ? .black.opacity(0.8)
                : theme.color(opacity: 0.4),
            radius: outerShadow,
            y: outerShadow / 3
        )
        .shadow(
            color: isDark ? .clear : .black.opacity(0.03),
            radius: 12,
            y: 4
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: state) { _, newState in
            if newState == .running {
                startTelemetry()
            } else {
                stopTelemetry()
            }
        }
        .onAppear {
            if state == .running {
                startTelemetry()
            }
        }
        .onDisappear {
            stopTelemetry()
        }
        .confirmationDialog("Delete VM?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await vmManager.deleteVM(id: config.id) }
            }
        } message: {
            Text("This will permanently delete \"\(config.name)\" and its disk image. This cannot be undone.")
        }
    }

    // MARK: - Inner Content

    private var innerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 16)

            osBadge
                .padding(.bottom, 32)

            telemetrySection
                .padding(.bottom, 32)

            Spacer(minLength: 0)

            footerRow
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            // Title + edit button
            HStack(spacing: 8) {
                Text(config.name)
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                if isHovering {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isDark ? .white : Color(hex: "6b7280"))
                            .frame(width: 28, height: 28)
                            .background(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }

            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                Text(state.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(
                        (isActive ? textColor : labelColor).opacity(0.8)
                    )

                Circle()
                    .fill(isActive ? Color(hex: "4ade80") : (isDark ? Color(hex: "4b5563") : Color(hex: "d1d5db")))
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: isActive ? Color(hex: "4ade80").opacity(0.8) : .clear,
                        radius: isActive ? 8 : 0
                    )
                    .opacity(isActive ? 1 : 1)
                    .animation(
                        isActive
                            ? .easeInOut(duration: 2).repeatForever(autoreverses: true)
                            : .default,
                        value: isActive
                    )
            }
            .padding(.top, 4)
        }
    }

    // MARK: - OS Badge

    private var osBadge: some View {
        Text("macOS Virtual Machine")
            .font(.system(size: 11, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(labelColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Telemetry

    @ViewBuilder
    private var telemetrySection: some View {
        if isActive {
            VStack(spacing: 20) {
                MochiMeter(label: "CPU Core", value: cpuUsage, theme: theme)
                MochiMeter(label: "RAM Alloc", value: ramUsage, theme: theme)
            }
        } else if state.isTransitional {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Starting macOS...")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(labelColor)
                }
                Spacer()
            }
            .frame(minHeight: 90)
        } else {
            HStack {
                Spacer()
                Text("Environment Asleep")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(labelColor.opacity(0.5))
                Spacer()
            }
            .frame(minHeight: 90)
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        VStack(spacing: 0) {
            // Top border separator
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                .frame(height: 1)

            HStack {
                // Uptime
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(isActive ? formattedUptime : "--:--")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .tracking(0.5)
                }
                .foregroundStyle(labelColor)

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    if isActive {
                        actionButton(icon: "terminal", tooltip: "Terminal") {
                            openWindow(value: config.id)
                        }
                        actionButton(icon: "display", tooltip: "Display") {
                            openWindow(value: config.id)
                        }
                        stopButton {
                            Task { await vmManager.stopVM(id: config.id) }
                        }
                    } else if state == .stopped {
                        deleteButton {
                            showDeleteConfirmation = true
                        }
                        playButton {
                            Task { await vmManager.startVM(id: config.id) }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Action Button Styles

    private func actionButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.8) : Color(hex: "64748b"))
                .frame(width: 48, height: 48)
                .background(isDark ? Color.white.opacity(0.1) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func stopButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: "FF5F57"))
                .frame(width: 20, height: 20)
                .frame(width: 48, height: 48)
                .background(isDark ? Color.white.opacity(0.1) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .help("Stop Environment")
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.2) : Color(hex: "d1d5db"))
                .frame(width: 48, height: 48)
                .background(isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .help("Delete Environment")
    }

    private func playButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "A855F7"))
                .frame(width: 48, height: 48)
                .background(isDark ? Color.white.opacity(0.1) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .help("Boot Environment")
    }

    // MARK: - Colors

    private var outerWrapperColor: Color {
        isDark ? Color(hex: "1c1c1e") : .white
    }

    private var innerFillColor: Color {
        if isDark {
            return isActive ? theme.color(opacity: 0.15) : Color.white.opacity(0.03)
        } else {
            return isActive ? theme.color(opacity: 0.5) : Color.black.opacity(0.02)
        }
    }

    private var textColor: Color {
        isDark ? .white.opacity(0.9) : Color(hex: "1f2937") // gray-800
    }

    private var labelColor: Color {
        isDark ? .white.opacity(0.5) : Color(hex: "6b7280") // gray-500
    }

    private var statusColor: Color {
        switch state {
        case .running: Color(hex: "4ade80") // green-400
        case .paused: .orange
        case .error: .red
        case .installing: .blue
        default: Color(hex: "d1d5db") // gray-300
        }
    }

    private var formattedUptime: String {
        let h = uptimeSeconds / 3600
        let m = (uptimeSeconds % 3600) / 60
        let s = uptimeSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Telemetry Simulation

    private func startTelemetry() {
        uptimeSeconds = 0
        cpuUsage = Double.random(in: 0.05...0.35)
        ramUsage = Double.random(in: 0.2...0.5)

        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                uptimeSeconds += 1
                cpuUsage = max(0.01, min(0.99, cpuUsage + Double.random(in: -0.03...0.03)))
                ramUsage = max(0.1, min(0.95, ramUsage + Double.random(in: -0.01...0.01)))
            }
        }
    }

    private func stopTelemetry() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
        uptimeSeconds = 0
        cpuUsage = 0
        ramUsage = 0
    }
}
