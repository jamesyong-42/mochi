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

    var body: some View {
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
        .padding(24)
        .frame(minHeight: 320)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .brightness(isHovering ? (isDark ? 0.03 : -0.01) : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
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

    // MARK: - Background

    private var cardBackground: Color {
        if isActive {
            return theme.color(opacity: isDark ? 0.08 : 0.25)
        }
        return isDark ? Color(NSColor.windowBackgroundColor) : .white
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Text(config.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isHovering {
                    EditPencilButton {
                        onEdit()
                    }
                    .transition(.opacity)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text(state.displayName.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(isActive ? AnyShapeStyle(.green) : AnyShapeStyle(.quaternary))
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - OS Badge

    private var osBadge: some View {
        Text("macOS Virtual Machine")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(minHeight: 90)
        } else {
            HStack {
                Spacer()
                Text("Environment Asleep")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(minHeight: 90)
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(isActive ? formattedUptime : "--:--")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 12) {
                    if isActive {
                        CardActionButton(tooltip: "Terminal") {
                            openWindow(value: config.id)
                        } content: {
                            Image(systemName: "terminal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        CardActionButton(tooltip: "Display") {
                            openWindow(value: config.id)
                        } content: {
                            Image(systemName: "display")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        CardActionButton(tooltip: "Stop Environment") {
                            Task { await vmManager.stopVM(id: config.id) }
                        } content: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.red)
                                .frame(width: 16, height: 16)
                        }
                    } else if state == .stopped {
                        DeleteActionButton {
                            showDeleteConfirmation = true
                        }

                        CardActionButton(tooltip: "Boot Environment") {
                            Task { await vmManager.startVM(id: config.id) }
                        } content: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch state {
        case .running: .green
        case .paused: .orange
        case .error: .red
        case .installing: .blue
        default: .secondary
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

// MARK: - Edit Pencil Button

private struct EditPencilButton: View {
    @State private var isHovering = false

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary.opacity(isHovering ? 1 : 0))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Card Action Button

private struct CardActionButton<Content: View>: View {
    var tooltip: String = ""
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content()
                .frame(width: 40, height: 40)
                .background(.quaternary.opacity(isHovering ? 1 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Delete Action Button

private struct DeleteActionButton: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isHovering ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                .frame(width: 40, height: 40)
                .background(.quaternary.opacity(isHovering ? 1 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help("Delete Environment")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
